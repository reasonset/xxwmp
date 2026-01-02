#!/bin/env ruby
require 'rubygems'
require 'bundler/setup'
require 'lmdb'
require 'roda'
require 'puma'
require 'rackup'
require 'rack/handler/puma' 
require 'securerandom'
require 'base64'
require 'digest'
require 'yaml'
require 'oj'

require_relative 'auth'
require_relative 'mediaplay'

def debug msg
  if ENV["DEBUG"] = "yes"
    if String === msg
      $stderr.puts msg
    else
      $stderr.puts msg.inspect
    end
  end
end

class Xxwmp < Roda
  SLIDE_EXPIRE = 60 * 60 * 72

  # RPATH =  File.expand_path("..", __dir__)
  RPATH = Bundler.root
  TOKENS = LMDB.new(File.join(RPATH, "var", "tokens"))
  TOKENS_DB = TOKENS.database
  USERS = LMDB.new(File.join(RPATH, "var", "users"))
  USERS_DB = USERS.database  
  CONFIG = YAML.load File.read File.join(RPATH, "config", "xxwmp.yaml")

  class BadRequest < StandardError
  end

  class NoSuch < StandardError
  end

  class IllegalPath < StandardError
  end

  class LackEnvironment < StandardError
  end
  
  class NoUser < StandardError
  end
  
  include Authenticater

  plugin :request_headers
  plugin :cookies, path: "/", same_site: :lax, http_only: true, secure: true

  route do |r|
    r.get "basic" do
      if user = basic_auth(r.headers["Authorization"])
        token = create_token(user)
        response.set_cookie("token", token)
        response.status = 204
        ""
      else
        response.status = 401
        response["WWW-Authenticate"] = 'Basic realm="xxwmp"'
        ""
      end
    end

    r.post "login" do
      debug "login"
      debug r.params
      params = r.params
      if user = post_auth(params["user"], params["password"])
        token = create_token(user)
        response.set_cookie("token", token)
        response.status = 204
        ""
      else
        response.status = 401
        ""
      end
    end

    r.get "auth" do
      debug "auth"
      rp = r.headers["X-Original-Request-Path"]
      user = rp.split("/")[2] # "" / API / USER / ...
      debug rp
      debug user
      begin
        if valid_token?(user, r.cookies["token"])
          response.status = 204
          ""
        else
          response.status = 401
          ""
        end
      rescue => e
        if NoUser === e
          response.status = 403
          ""
        else
          response.status = 500
          response["Content-Type"] = "text/plain"
          ""
        end
      end
    end
    
    r.get "authcheck" do
      user = getuser_from_token(r.cookies["token"])
      if user
        Oj.dump({"user" =>  user})
      else
        response.status = 401
        ""
      end
    end

    r.on %r:browse/([^/]+)(/.*)?: do |user, path|
      # rp = r.headers["X-Original-Request-Path"]
      # user = rp.split("/")[2]
      
      begin
        browser = MediaPlayer.new(CONFIG, user, path)
        val = browser.dir
        
        response["Content-Type"] = "application/json"
        Oj.dump val
      rescue => e
        if BadRequest === e || IllegalPath === e
          response.status = 400
          ""
        elsif NoSuch === e
          response.status = 404
          ""
        else
          response.status = 500
          response["Content-Type"] = "text/plain"
          ""
        end
      end
    end
    
    r.get("config") do
      Oj.dump({
        "server_name" => CONFIG["server_name"],
        "use_metadata" => false
      })
    end
  end
end

Rackup::Handler::Puma.run Xxwmp.app, Host: Xxwmp::CONFIG["server_host"], Port: Xxwmp::CONFIG["server_port"]

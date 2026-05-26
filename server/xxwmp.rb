#!/bin/env ruby
require 'rubygems'
require 'bundler/setup'
require 'lmdb'
require 'roda'
require 'puma'
require 'rackup'
require 'rack/handler/puma' 
require 'digest'
require 'yaml'
require 'oj'

require_relative 'auth'
require_relative 'mediaplay'
require_relative 'metadata'

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
  PUBKEY_CHALLENGE = LMDB.new(File.join(RPATH, "var", "pubkey-challenge"))
  PUBKEY_CHALLENGE_DB = PUBKEY_CHALLENGE.database
  PUBKEY = LMDB.new(File.join(RPATH, "var", "pubkey"))
  PUBKEY_DB = PUBKEY.database
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
  plugin :json_parser

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
      
      user = case CONFIG["auth_method"]
      when "publickey"
        pubkey_auth(
          signature: params["signature"],
          publickey: params["publicKey"],
          token: params["token"]
        )
      else
        post_auth(params["user"], params["password"])
      end

      if user
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
      debug r.params
      rp = r.headers["X-Original-Request-Path"]
      user = rp.split("/")[2] # "" / API / USER / ...
      debug rp
      debug user
      begin
        if valid_token?(user, r.cookies["token"])
          response.status = 204
          ""
        else
          unauthorized response
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
        unauthorized response
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
          debug e
          response.status = 400
          ""
        elsif NoSuch === e
          response.status = 404
          ""
        else
          debug e
          response.status = 500
          response["Content-Type"] = "text/plain"
          ""
        end
      end
    end

    r.post("metadata", String) do |user|
      begin
        metaobj = XXWMPMetadata.new(CONFIG, user)
        debug user
        debug r.params
        result = metaobj.get r.params["missing_metadata"]
        debug result
        Oj.dump result
      rescue => e
        debug e
        if XXWMPMetadata::MetadataDisabledError
          response.status = 404
          ""
        elsif XXWMPMetadata::BadRequestError
          response.status = 400
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
        "use_metadata" => CONFIG["use_metadata"],
        "use_thumbnail" => CONFIG["use_thumbnail"],
        "videoplayer" => CONFIG["videoplayer"] || "default",
        "audioplayer" => CONFIG["audioplayer"] || "default"
      })
    end
  end
end

Rackup::Handler::Puma.run Xxwmp.app, Host: Xxwmp::CONFIG["server_host"], Port: Xxwmp::CONFIG["server_port"]

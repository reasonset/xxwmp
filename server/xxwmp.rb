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

class Xxwmp < Roda
  SLIDE_EXPIRE = 60 * 60 * 72
  def initialize(*arg)
    super
    # @rpath =  File.expand_path("..", __dir__)
    @rpath = Bundler.root
    @tokens = LMDB.new(File.join(@rpath, "var", "tokens"))
    @tokens_db = @tokens.database
    @users = LMDB.new(File.join(@rpath, "var", "users"))
    @users_db = @users.database
  end

  def basic_auth(auth)
    return false if !auth || auth !~ /^Basic (\S+)$/
    user, pw = Base64.decode64($1).split(":")
    valid_pw = @users_db[user]
    return false unless Digest::SHA256.hexdigest(pw) == valid_pw
    
    user
  end

  def create_token(user, token=nil, now=nil)
    token ||= SecureRandom.alphanumeric(32)
    now ||= Time.now.to_i
    @tokens.transaction do
      @tokens_db[token] = "#{user}:#{now + SLIDE_EXPIRE}"
    end

    token
  end

  def valid_token?(user, token)
    return false unless user
    now = Time.now.to_i
    val = @tokens_db[token]
    $stderr.puts val
    return false unless val
    u, x = val.split(":")
    $stderr.puts u
    $stderr.puts user
    return false unless user == u
    $stderr.puts now
    $stderr.puts x.to_i
    return false if now > x.to_i
    create_token(u, token, now)

    true
  end

  plugin :request_headers
  plugin :cookies, path: "/", same_site: :lax, http_only: true, secure: true

  route do |r|
    r.get "login" do
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

    r.get "auth" do
      $stderr.puts r.params
      $stderr.puts r.cookies
      rp = r.headers["X-Original-Request-Path"]
      user = rp.split("/")[2] # "" / API / USER / ...
      if valid_token?(user, r.cookies["token"])
        response.status = 204
        ""
      else
        response.status = 401
        ""
      end
    end

    r.on %r:browse/([^/]+)(/.*)?: do |user, path|
      # rp = r.headers["X-Original-Request-Path"]
      # user = rp.split("/")[2]
      $stderr.puts user
      $stderr.puts path.inspect
      response["Content-Type"] = "text/plain"
      user 
    end
  end
end

Rackup::Handler::Puma.run Xxwmp.app, Host: "127.5.0.1", Port: 8000

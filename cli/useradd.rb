#!/bin/env ruby
require 'rubygems'
require 'bundler/setup'
require 'lmdb'
require 'digest'
require 'yaml'

print "User ID? "
user_id = $stdin.gets.chomp

print "Password? "
password = $stdin.gets.chomp

if !user_id || !password || user_id.empty? || password.empty?
  exit 1
end

rpath = Bundler.root
config = YAML.load File.read File.join(rpath, "config", "xxwmp.yaml")
users = LMDB.new(File.join(rpath, "var", "users"))
users_db = users.database
users.transaction do
  users_db[user_id] = Digest::SHA256.hexdigest(config["password_seed"] + password)
end
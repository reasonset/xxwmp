#!/bin/env ruby
require 'rubygems'
require 'bundler/setup'
require 'lmdb'
require 'digest'

@rpath = Bundler.root
users = LMDB.new(File.join(@rpath, "var", "users"))
users_db = users.database
users.transaction do
  users_db["jrh"] = Digest::SHA256.hexdigest "foo"
end
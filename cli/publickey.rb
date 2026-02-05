#!/bin/env ruby
require 'rubygems'
require 'bundler/setup'
require 'lmdb'

action = ARGV.shift
RPATH = Bundler.root

fp = File.join(RPATH, "var", "pubkey")
lmdb = LMDB.new(fp)
db = lmdb.database

case action.downcase
when "add"
  user = ARGV.shift
  pubkey = ARGV.shift
  if !user || user.empty? || !pubkey || pubkey.empty? || pubkey[-1] != "="
    abort "publickey.rb add <user> <public_key>"
  end

  lmdb.transaction do
    db[pubkey] = user  
  end
when "remove"
  pubkey = ARGV.shift
  if !pubkey || pubkey.empty? || pubkey[-1] != "="
    abort "publickey.rb remove <public_key>"
  end

  lmdb.transaction do
    db.delete pubkey
  end
end
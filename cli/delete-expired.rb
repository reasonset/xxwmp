#!/bin/env ruby
require 'rubygems'
require 'bundler/setup'
require 'lmdb'
require 'oj'

RPATH = Bundler.root
NOW = Time.now.to_i

fp = File.join(RPATH, "var", "tokens")
if File.exist?(File.join(fp, "data.mdb"))
  lmdb = LMDB.new(fp)
  db = lmdb.database

  lmdb.transaction do
    db.each do |k,v|
      user, expire = v.split(":")
      expire = expire.to_i
      if expire < NOW
        puts "Delete #{k}"
        db.delete(k)
      end
    end
  end
end

fp = File.join(RPATH, "var", "pubkey-challenge")
if File.exist?(File.join(fp, "data.mdb"))
  lmdb = LMDB.new(fp)
  db = lmdb.database

  lmdb.transaction do
    db.each do |k,v|
      data = Oj.load v
      if data["expire"] < NOW
        puts "Delete #{k}"
        db.delete(k)
      end
    end
  end
end
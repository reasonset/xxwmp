#!/bin/env ruby
require 'json'
require 'fileutils'

class XXWMPMetadata < Roda
  IMAGE_MIME = {
    ".jpeg" => "jpeg",
    ".jpg" => "jpeg",
    ".png" => "png",
    ".webp" => "webp"
  }

  class MetadataDisabledError < StandardError
  end

  class BadRequestError < StandardError
  end

  def initialize(config, user)
    @root = config["media_root"]
    @user_media_root = [config["media_root"], user].join("/")
    @meta_root = config["meta_root"]
    @user_meta_root = [@meta_root, user].join("/")
    @ffprobe = config["ffprobe"] || "ffprobe"
    Encoding.default_external = "UTF-8"

    if !config["use_metadata"] || !@meta_root || @meta_root.empty? || !File.directory?(@meta_root)
      raise MetadataDisabledError
    end
  end

  def get list
    raise BadRequestError unless Array === list
    rv = {}

    list.each do |path|
      begin
        File.realpath(path, @user_media_root)
      rescue => e
        $stderr.puts e
        next
      end
      metapath = File.expand_path(path + ".info.json", @user_meta_root)
      $stderr.puts metapath

      if File.exist?(metapath)
        rv[path] = JSON.load File.read metapath
      else
        meta = load_meta path
        FileUtils.mkdir_p(File.dirname metapath) unless File.exist? File.dirname metapath
        File.open(metapath, "w") {|f| JSON.dump meta, f }
        rv[path] = meta
      end
    end

    rv
  end

  def load_meta path
    result = nil
    filepath = [@user_media_root, path].join("/")
    $stderr.puts filepath
    $stderr.puts File.exist? filepath
    return nil unless File.exist? filepath
    IO.popen([@ffprobe, "-of", "json", "-show_format", "-show_streams", filepath], external_encoding: "UTF-8") do |io|
      idata = io.read
      data = JSON.load idata
      meta = data["format"]["tags"]
      return nil unless meta

      result = {
        "tags" => {
          "title" => meta["title"] || meta["Title"] || meta["TITLE"],
          "artist" => meta["artist"] || meta["Artist"] || meta ["ARTIST"],
          "album" => meta["album"] || meta["Album"] || meta["ALBUM"]
        }
      }

      dir = File.dirname filepath
      if File.directory? dir
        dir_files = Dir.children(dir)
        image_files = dir_files.select {|i| File.fnmatch("{cover,front}.{jpeg,jpg,png,webp}", i, File::FNM_EXTGLOB)}
        result["tags"]["artwork"] = [] unless image_files.empty?
        image_files.each do |i|
          cover = {
            "src" => "/media/#{File.dirname path}/#{i}",
            "type" => "image/#{IMAGE_MIME[File.extname(i).downcase]}"
          }
          result["tags"]["artwork"].push cover
        end
      end
    end
    result
  end
end

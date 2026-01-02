# @license Apache-2.0
# Copyright (c) 2026 Masaki Haruka
# 
# This file is a modified version of the original source from:
# github.com/reasonset/localwebmediaplayer
# (Modified to integrate with XXWMP)

class Xxwmp < Roda
  module DirList

    MEDIA_EXT_VID = %w:.mp4 .mkv .mov .webm .ogv:
    MEDIA_EXT_AUD = %w:.mp3 .ogg .oga .opus .m4a .aac .flac .wav:
    MEDIA_EXT_IMG = %w:.jpg .jpeg .jfif .pjpeg .pjp .png .webp .avif .bmp .gif:
    MEDIA_EXT_TXT = %w:.txt .xml .html .xhtml .css .json .yaml .yml .toml .md .rst .t2t .wiki:
    MEDIA_EXT_EXT = %w:.pdf:

    def dir
      path = @path.empty? ? nil : @path
      dirpath = path ? File.join(@root, path) : @root
      files = {
        "directory" => [],
        "file" => [],
        "cover" => nil
      }
      Dir.children(dirpath).each do |fn|
        fn.force_encoding("UTF-8")
        next if fn[0] == "."
        stat = File::Stat.new(File.join(dirpath, fn))

        if stat.directory?
          files["directory"].push({
            "type" => "directory",
            "path" => path ? File.join(path, fn) : fn
          })
        elsif File.fnmatch("{cover,front}.{jpg,png}", fn, File::FNM_EXTGLOB)
          files["cover"] ||= (path ? File.join(path, fn) : fn)
        elsif stat.file? || File.file?(File.realpath(File.join(dirpath, fn)))
          ext = File.extname(fn)
          if MEDIA_EXT_VID.include? ext.downcase
            files["file"].push({
              "type" => "video",
              "path" => (path ? File.join(path, fn) : fn),
              "ext" => ext
            })
          elsif MEDIA_EXT_AUD.include? ext.downcase
            files["file"].push({
              "type" => "music",
              "path" => (path ? File.join(path, fn) : fn),
              "ext" => ext
            })
          elsif MEDIA_EXT_IMG.include? ext.downcase
            files["file"].push({
              "type" => "image",
              "path" => (path ? File.join(path, fn) : fn),
              "ext" => ext
            })
          elsif MEDIA_EXT_TXT.include? ext.downcase
            files["file"].push({
              "type" => "plain",
              "path" => (path ? File.join(path, fn) : fn),
              "ext" => ext
            })
          elsif MEDIA_EXT_EXT.include? ext.downcase
            files["file"].push({
              "type" => "external-link",
              "path" => (path ? File.join(path, fn) : fn),
              "ext" => ext
            })
          elsif ext.downcase == ".m3u"
            begin
              list = File.read(path ? File.join(@root, path, fn) : File.join(@root, fn)).each_line.reject {|i| i =~ /^\s*#/ || i =~ /^\s*$/ }.map {|i| i.chomp }

              unless list.any? {|i| i[0] == "/" || i =~ %r!(?:^|/)\.\.(?:$|/)! }
                files["file"].push({
                  "type" => "list",
                  "path" => (path ? File.join(path, fn) : fn),
                  "list" => list.map {|i| path ? File.join(path, i) : i }
                })
              end
            rescue
              # Invalid playlist item
              nil
            end
          end
        end
      end

      # Re-sorting with UTF-8 Filename
      files["directory"].sort_by! {|i| File.basename i["path"] }
      files["file"].sort_by! {|i| File.basename i["path"] }

      files
    end
  end

  class MediaPlayer
    include DirList

    def initialize config, user, path
      @config = config
      @user = user
      path = "/" if !path || path.empty?
      @path = path.sub(%r:^/+:, "").gsub(%r:/{2,}:, "/")

      @root = File.join config["media_root"], user

      ########################
      # Sanitize malformed path
      path = @path.empty? ? nil : @path
      dirpath = path ? File.join(@root, path) : @root
      root_real = File.realpath(File.expand_path(@root)).sub(%r:/?$:, "/")
      if !File.exist?(dirpath)
        raise NoSuch
      end
      dirpath = File.realpath(File.expand_path(dirpath)).sub(%r:/?$:, "/")

      if (@path.include?('\\')) || @path.split("/").include?("..") || dirpath[0, root_real.size] != root_real
        raise IllegalPath
      end
      ########################
    end
  end
end
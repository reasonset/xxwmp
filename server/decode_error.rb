#!/bin/env ruby

class XXWMPDecodeErrorReport < Roda
  class BadRequestError < StandardError
  end
  
  class NotFoundError < StandardError
  end

  def initialize(config, user)
    @report_file = File.join(config["data_root"], "audio_decode_error_report", sprintf("%.3f.json", Time.now.to_f))
    @user = user
  end

  def push params
    path_decoded = params["path_decoded"]
    path_split = path_decoded.split(/[\\\/]/)
    if !path_decoded || path_decoded[0] == "/" || path_split.include?("..") || path_split[1] != @user || reported_path[0, 7] != "/media/"
      raise BadRequest
    end
    real_path = File.realpath(File.join($config[:media_root], path_decoded))

    File.open(@report_file, "w") do |f|
      JSON.dump({
        "path" => params["reported_path"],
        "decoded" => params["path_decoded"],
        "source" => real_path,
        "user" => @user
      }, f)
    end
  rescue Errno::ENOENT
    raise NotFoundError
  end
end
class Xxwmp < Roda
  module Authenticater
    def basic_auth(auth)
      return false if !auth || auth !~ /^Basic (\S+)$/
      user, pw = Base64.decode64($1).split(":")
      return false if !user || user.empty?
      valid_pw = USERS_DB[user]
      return false unless Digest::SHA256.hexdigest(pw) == valid_pw
      
      user
    end

    def post_auth(user, pw)
      return false if !user || user.empty?
      valid_pw = USERS_DB[user]
      return false unless Digest::SHA256.hexdigest(pw) == valid_pw
      
      user
    end
    
    def create_token(user, token=nil, now=nil)
      token ||= SecureRandom.alphanumeric(32)
      now ||= Time.now.to_i
      TOKENS.transaction do
        TOKENS_DB[token] = "#{user}:#{now + SLIDE_EXPIRE}"
      end
  
      token
    end
    
    def valid_token?(user, token)
      raise NoUser if !user || user.empty?
      return false unless token
      now = Time.now.to_i
      val = TOKENS_DB[token]
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
    
    def getuser_from_token(token)
      return nil if !token || token.empty?
      TOKENS_DB[token]&.split(":")&.first
    end
  end
end
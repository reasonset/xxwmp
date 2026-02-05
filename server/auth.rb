require 'securerandom'
require 'openssl'
require 'base64'
require 'oj'

class Xxwmp < Roda
  module Authenticater
    def basic_auth(auth)
      return false if !auth || auth !~ /^Basic (\S+)$/
      user, pw = Base64.decode64($1).split(":")
      return false if !user || user.empty?
      valid_pw = USERS_DB[user]
      return false unless Digest::SHA256.hexdigest(Xxwmp::CONFIG["password_seed"] + pw) == valid_pw
      
      user
    end

    def post_auth(user, pw)
      return false if !user || user.empty?
      valid_pw = USERS_DB[user]
      return false unless Digest::SHA256.hexdigest(Xxwmp::CONFIG["password_seed"] + pw) == valid_pw
      
      user
    end

    def create_publickey_challenge
      token = SecureRandom.uuid
      secret = SecureRandom.alphanumeric
      PUBKEY_CHALLENGE.transaction do
        PUBKEY_CHALLENGE_DB[token] = Oj.dump({
          "secret" => secret,
          "expire" => Time.now.to_i + (60*5)
        })
      end
      {"secret" => secret, "challenge_token" => token}
    end

    def pubkey_auth(signature:, publickey:, token:)
      challenge = PUBKEY_CHALLENGE_DB[token]
      return nil unless challenge
      challenge = Oj.load challenge
      now = Time.now.to_i
      return nil if now > challenge["expire"]
      sig_bin = Base64.decode64(signature)
      pubkey = OpenSSL::PKey.read(["-----BEGIN PUBLIC KEY-----", publickey, "-----END PUBLIC KEY-----"].join("\n"))
      
      if pubkey.verify(nil, sig_bin, challenge["secret"])
        PUBKEY_DB[publickey]
      else
        nil
      end
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
      return false unless val
      u, x = val.split(":")
      return false unless user == u
      return false if now > x.to_i
      create_token(u, token, now)
  
      true
    end
    
    def getuser_from_token(token)
      return nil if !token || token.empty?
      TOKENS_DB[token]&.split(":")&.first
    end

    def unauthorized response
      response.status = 401
      case CONFIG["auth_method"]
      when "publickey"
        challenge_params = create_publickey_challenge
        response["WWW-Authenticate"] = "PublicKey"
        response["Content-Type"] = "application/json"
        Oj.dump(challenge_params)
      else
        response["WWW-Authenticate"] = "Password"
        ""
      end
    end
  end
end
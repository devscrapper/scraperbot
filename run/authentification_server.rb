require 'rubygems'
require 'eventmachine'
require 'em-http'
require 'json'
require 'json/ext'
require 'digest/sha2'

module AuthentificationServer
  USER = "userftp"
   attr :tokens

  def initialize(tokens)
    @tokens = tokens
  end

  def post_init
    puts "-- someone connected to Authentification Server! "
  end

  def receive_data param
   data =  JSON.parse param

    case data["cmd"]
      when "get"
        pwd = new_pwd
        reponse = {"user" => USER, "pwd" => pwd}
        @tokens << new_token(pwd)
        send_data (JSON.generate(reponse))
       close_connection_after_writing
      when "check"
        user = data["user"]
        pwd = data["pwd"]
        response = [{"check" => check_token(pwd)}]
        send_data (JSON.generate(response) )
        close_connection_after_writing
      when "delete"
        user = data["user"]
        pwd = data["pwd"]
        delete_token(pwd)
        close_connection
      when "exit"
        close_connection
        EventMachine.stop
      else
    end
  end

  def unbind
    puts "-- someone disconnected from the Authentification Server! #"
  end


  def new_pwd()
    rand(999999999).to_s
  end
  def new_user()
    USER
  end
  def new_token(message)
    sha256 = Digest::SHA256.new
    sha256.digest message
  end
  def check_token(pwd)
    sha256 = Digest::SHA256.new
    return @tokens.include?(sha256.digest pwd) unless pwd.nil?
    false  if  pwd.nil?
  end
  def delete_token(pwd)
    sha256 = Digest::SHA256.new
    @tokens.delete(sha256.digest pwd) unless pwd.nil?
  end
end



EventMachine.run {
  Signal.trap("INT") { EventMachine.stop }
  Signal.trap("TERM") { EventMachine.stop }
  tokens = Array.new

  EventMachine.start_server "127.0.0.1", 8081, AuthentificationServer , tokens
}

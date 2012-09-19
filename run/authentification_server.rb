require 'rubygems'        # if you use RubyGems
require 'eventmachine'
require 'json'
require 'json/ext'
require 'digest/sha2'
require File.dirname(__FILE__) + '/../lib/logging'
require 'logger'


module AuthentificationServer

  def initialize()
  end

  def post_init
  end

  def receive_data param
    port, ip = Socket.unpack_sockaddr_in(get_peername)
    data = JSON.parse param
    who = data["who"]
    Logging.send($log_file, Logger::DEBUG, "data receive : #{data}")
    case data["cmd"]
      when "get"
        pwd = new_pwd
        user = new_user
        reponse = {"user" => user, "pwd" => pwd}
        new_token(user, pwd)
        send_data (JSON.generate(reponse))
        Logging.send($log_file, Logger::INFO, "push new authentification to #{who}(#{ip}:#{port})")
        p "push new authentification to #{who}(#{ip}:#{port})"
        close_connection_after_writing
      when "check"
        user = data["user"]
        pwd = data["pwd"]
        response = {"check" => check_token(user, pwd)}
        send_data (JSON.generate(response))
        Logging.send($log_file, Logger::INFO, "check authentification for #{who}(#{ip}:#{port})")
        close_connection_after_writing
        p "check authentification for #{who}(#{ip}:#{port})"
      when "delete"
        user = data["user"]
        pwd = data["pwd"]
        delete_token(user, pwd)
        Logging.send($log_file, Logger::INFO, "delete authentification for #{who}(#{ip}:#{port})")
        close_connection
        p "delete authentification for #{who}(#{ip}:#{port})"
      when "delete_all"
        delete_all()
        Logging.send($log_file, Logger::INFO, "delete all authentifications for #{who}(#{ip}:#{port})")
        close_connection
        p "delete all authentifications for #{who}(#{ip}:#{port})"
      when "list"
        send_data ($tokens)
        close_connection_after_writing
        p "push all tokens to #{ip}:#{port}"
        Logging.send($log_file, Logger::INFO, "push all tokens to #{ip}:#{port}")
      when "exit"
        close_connection
        EventMachine.stop
      else
        Logging.send($log_file, Logger::ERROR, "unknown action : #{data["cmd"]} from  #{ip}:#{port}")
    end
  end

  def unbind
  end

  def new_pwd()
    rand(999999999).to_s
  end

  def new_user()
    rand(999999999).to_s
  end

  def new_token(user, pwd)
    sha256 = Digest::SHA256.new
    $sem.synchronize { $tokens << (sha256.digest (user + pwd)) }
  end

  def check_token(user, pwd)
    return false if  pwd.nil? or user.nil?
    begin
      sha256 = Digest::SHA256.new
      $sem.synchronize { $tokens.include?(sha256.digest (user + pwd)) unless pwd.nil? and user.nil? }
    rescue Exception => e
      Logging.send($log_file, Logger::ERROR, e.message, __LINE__, __method__)
      false
    end
  end

  def delete_token(user, pwd)
    return false if  pwd.nil? or user.nil?
    begin
      sha256 = Digest::SHA256.new
      $sem.synchronize { $tokens.delete(sha256.digest (user + pwd)) unless  pwd.nil? and user.nil? }
    rescue Exception => e
      Logging.send($log_file, Logger::ERROR, e.message, __LINE__, __method__)
      false
    end
  end

  def delete_all()
    begin
      $sem.synchronize { $tokens = $tokens.drop($tokens.size) }
    rescue Exception => e
      Logging.send($log_file, Logger::ERROR, e.message, __LINE__, __method__)
      false
    end
  end
end


#--------------------------------------------------------------------------------------------------------------------
# INIT
#--------------------------------------------------------------------------------------------------------------------
$tokens = Array.new
$sem = Mutex.new
$log_file = File.dirname(__FILE__) + "/../log/" + File.basename(__FILE__, ".rb") + ".log"
listening_port = 9001
accepted_ip = "localhost" #le serveur est installé sur la même machine que ftp server et scraper server,
# on accepte alors que des connections locales.



#--------------------------------------------------------------------------------------------------------------------
# INPUT
#--------------------------------------------------------------------------------------------------------------------
ARGV.each{|arg|
  listening_port = arg.split("=")[1] if arg.split("=")[0] == "--port"
  accepted_ip = arg.split("=")[1] if arg.split("=")[0] == "--accepted_ip"
} if ARGV.size > 0


Logging.send($log_file, Logger::INFO, "parameters of authentification server : ")
Logging.send($log_file, Logger::INFO, "accepted ip : #{accepted_ip}")
Logging.send($log_file, Logger::INFO, "listening port : #{listening_port}")
#--------------------------------------------------------------------------------------------------------------------
# MAIN
#--------------------------------------------------------------------------------------------------------------------
EventMachine.run {
  Signal.trap("INT") { EventMachine.stop }
  Signal.trap("TERM") { EventMachine.stop }
  Logging.send($log_file, Logger::INFO, "authentification server is starting")
  EventMachine.start_server accepted_ip, listening_port, AuthentificationServer
}
Logging.send($log_file, Logger::INFO, "authentification server stopped")




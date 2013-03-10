require 'rubygems' # if you use RubyGems
require 'eventmachine'
require 'json'
require 'json/ext'
require 'digest/sha2'
require File.dirname(__FILE__) + '/../lib/logging'
require 'logger'
require 'yaml'
require File.dirname(__FILE__) + '/../model/authentification'
require File.dirname(__FILE__) + '/../lib/common'

module AuthentificationServer
  include Common

  def receive_data param
    debug ("data receive : #{param}")

    begin
      Thread.new { execute_task(YAML::load param) }
    rescue Exception => e
      warning("data receive #{param} : #{e.message}")
    end
  end

  def execute_task(data)
    case data["cmd"]
      when "get"
        authentification = Authentification.new(new_user, new_pwd)
        new_token(authentification)
        send_data (YAML::dump authentification)
        information("push new authentification")
        close_connection_after_writing
      when "check"
        authentification = data["authentification"]
        send_data (YAML::dump check_token(authentification))
        information("check authentification")
        close_connection_after_writing
      when "delete"
        authentification = data["authentification"]
        delete_token(authentification)
        information("delete authentification")
        close_connection
      when "delete_all"
        delete_all()
        information("delete all authentifications")
        close_connection
      when "list"
        send_data ($tokens)
        close_connection_after_writing
        information("push all tokens")
      when "exit"
        close_connection
        EventMachine.stop
      else
        port, ip = Socket.unpack_sockaddr_in(get_peername)
        alert("unknown action : #{data["cmd"]} from  #{ip}:#{port}")
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

  def new_token(authen)
    sha256 = Digest::SHA256.new
    $sem.synchronize { $tokens << (sha256.digest (authen.user + authen.pwd)) }
  end

  def check_token(authen)
    return false if  authen.nil?
    begin
      sha256 = Digest::SHA256.new
      $sem.synchronize { $tokens.include?(sha256.digest (authen.user + authen.pwd)) unless authen.pwd.nil? and authen.user.nil? }
    rescue Exception => e
      error(e.message, __LINE__)
      false
    end
  end

  def delete_token(authen)
    return false if   authen.nil?
    begin
      sha256 = Digest::SHA256.new
      $sem.synchronize { $tokens.delete(sha256.digest (authen.user + authen.pwd)) unless  authen.pwd.nil? and authen.user.nil? }
    rescue Exception => e
      error(e.message, __LINE__)
      false
    end
  end

  def delete_all()
    begin
      $sem.synchronize { $tokens = $tokens.drop($tokens.size) }
    rescue Exception => e
      error(e.message, __LINE__)
      false
    end
  end
end


#--------------------------------------------------------------------------------------------------------------------
# INIT
#--------------------------------------------------------------------------------------------------------------------
$tokens = Array.new
$sem = Mutex.new
PARAMETERS = File.dirname(__FILE__) + "/../parameter/" + File.basename(__FILE__, ".rb") + ".yml"
$log_file = File.dirname(__FILE__) + "/../log/" + File.basename(__FILE__, ".rb") + ".log"
listening_port = 9153
$envir="production"

#--------------------------------------------------------------------------------------------------------------------
# INPUT
#--------------------------------------------------------------------------------------------------------------------
ARGV.each { |arg|
  $envir = arg.split("=")[1] if arg.split("=")[0] == "--envir"
} if ARGV.size > 0

begin
  params = YAML::load(File.open(PARAMETERS), "r:UTF-8")
  listening_port = params[$envir]["listening_port"] unless params[$envir]["listening_port"].nil?
rescue Exception => e
  Common.warning("parameters file #{PARAMETERS} is not found : #{e.message}")
end

Common.information ("parameters of authentification server : ")
Common.information ("listening port : #{listening_port}")
#--------------------------------------------------------------------------------------------------------------------
# MAIN
#--------------------------------------------------------------------------------------------------------------------
Common.information("environement : #{$envir}")
#TODO remplacer passage de parametre par un fichier de param pour envir sur tous les run _server
EventMachine.run {
  Signal.trap("INT") { EventMachine.stop }
  Signal.trap("TERM") { EventMachine.stop }
  Common.information ("authentification server is starting")
  EventMachine.start_server "localhost", listening_port, AuthentificationServer
}
Common.information ("authentification server stopped")




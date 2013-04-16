require 'rubygems' # if you use RubyGems
require 'eventmachine'
#require 'json'
#require 'json/ext'
#require 'digest/sha2'
require 'yaml'

require_relative '../lib/logging'
require_relative '../model/authentification'


module AuthentificationServer
  attr :logger

  def initialize(logger)
    @logger = logger
  end

  def receive_data param
    @logger.an_event.debug ("data receive : #{param}")

    begin
      Thread.new { execute_task(YAML::load param) }
    rescue Exception => e
      @logger.an_event.error "cannot execute task"
      @logger.an_event.debug e
    end
  end

  def execute_task(data)
    case data["cmd"]
      when "get"
        authentification = Authentification.new(new_user, new_pwd)
        new_token(authentification)
        send_data (YAML::dump authentification)
        @logger.an_event.info ("push new authentification")
        close_connection_after_writing
      when "check"
        authentification = data["authentification"]
        send_data (YAML::dump check_token(authentification))
        @logger.an_event.info ("check authentification")
        close_connection_after_writing
      when "delete"
        authentification = data["authentification"]
        delete_token(authentification)
        @logger.an_event.info ("delete authentification")
        close_connection
      when "delete_all"
        delete_all()
        @logger.an_event.info ("delete all authentifications")
        close_connection
      when "list"
        send_data ($tokens)
        close_connection_after_writing
        @logger.an_event.info ("push all tokens")
      when "exit"
        close_connection
        EventMachine.stop
      else
        port, ip = Socket.unpack_sockaddr_in(get_peername)
        @logger.an_event.warn ("unknown action : #{data["cmd"]} from  #{ip}:#{port}")
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
ENVIRONMENT= File.dirname(__FILE__) + "/../parameter/environment.yml"

listening_port = 9153
$staging="production"

#--------------------------------------------------------------------------------------------------------------------
# INPUT
#--------------------------------------------------------------------------------------------------------------------
begin
  environment = YAML::load(File.open(ENVIRONMENT), "r:UTF-8")
  $staging = environment["staging"] unless environment["staging"].nil?
rescue Exception => e
  STDERR << "loading parameter file #{ENVIRONMENT} failed : #{e.message}"
end
begin
  params = YAML::load(File.open(PARAMETERS), "r:UTF-8")
  listening_port = params[$staging]["listening_port"] unless params[$staging]["listening_port"].nil?
  scrape_server_port = params[$staging]["scrape_server_port"] unless params[$staging]["scrape_server_port"].nil?
  periodicity = params[$staging]["periodicity"] unless params[$staging]["periodicity"].nil?
  $debugging = params[$staging]["debugging"] unless params[$staging]["debugging"].nil?
rescue Exception => e
  STDERR << "loading parameters file #{PARAMETERS} failed : #{e.message}"
end

logger = Logging::Log.new(self, :staging => $staging, :id_file => File.basename(__FILE__, ".rb"), :debugging => $debugging)

logger.a_log.info "parameters of authentification server :"
logger.a_log.info "listening port : #{listening_port}"
logger.a_log.info "debugging : #{$debugging}"
logger.a_log.info "staging : #{$staging}"
#--------------------------------------------------------------------------------------------------------------------
# MAIN
#--------------------------------------------------------------------------------------------------------------------
EventMachine.run {
  Signal.trap("INT") { EventMachine.stop }
  Signal.trap("TERM") { EventMachine.stop }
  logger.a_log.info "authentification server is running"
  EventMachine.start_server "localhost", listening_port, AuthentificationServer, logger
}
logger.a_log.info "authentification server stopped"




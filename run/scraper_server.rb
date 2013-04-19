#!/usr/bin/env ruby -w
# encoding: UTF-8
require 'yaml'
require_relative '../lib/logging'
require_relative '../model/tasking/task_connection'


#--------------------------------------------------------------------------------------------------------------------
# INIT
#--------------------------------------------------------------------------------------------------------------------
PARAMETERS = File.dirname(__FILE__) + "/../parameter/" + File.basename(__FILE__, ".rb") + ".yml"
ENVIRONMENT= File.dirname(__FILE__) + "/../parameter/environment.yml"
listening_port = 9151 # port d'ecoute du scrape_server
$authentification_server_port = 9153
$calendar_server_port=9154
$ftp_server_port = 9152
$input_flows_server_ip = "localhost"
$input_flows_server_port = 9101
$statupweb_server_ip = "localhost"
$statupweb_server_port = 3000
$staging = "production"
$debugging = false
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
  $calendar_server_port = params[$staging]["calendar_server_port"] unless params[$staging]["calendar_server_port"].nil?
  $authentification_server_port = params[$staging]["authentification_server_port"] unless params[$staging]["authentification_server_port"].nil?
  $input_flows_server_ip = params[$staging]["input_flows_server_ip"] unless params[$staging]["input_flows_server_ip"].nil?
  $input_flows_server_port = params[$staging]["input_flows_server_port"] unless params[$staging]["input_flows_server_port"].nil?
  $statupweb_server_ip = params[$staging]["statupweb_server_ip"] unless params[$staging]["statupweb_server_ip"].nil?
  $statupweb_server_port = params[$staging]["statupweb_server_port"] unless params[$staging]["statupweb_server_port"].nil?
  $ftp_server_port = params[$staging]["ftp_server_port"] unless params[$staging]["ftp_server_port"].nil?
  $debugging = params[$staging]["debugging"] unless params[$staging]["debugging"].nil?
rescue Exception => e
  STDERR << "loading parameters file #{PARAMETERS} failed : #{e.message}"
end

logger = Logging::Log.new(self, :staging => $staging, :id_file => File.basename(__FILE__, ".rb"), :debugging => $debugging)

logger.a_log.info "parameters of calendar server :"
logger.a_log.info "listening port : #{listening_port}"
logger.a_log.info "calendar server port : #{$calendar_server_port}"
logger.a_log.info "authentification server port : #{$authentification_server_port}"
logger.a_log.info "input flows server : #{$input_flows_server_ip}:#{$input_flows_server_port}"
logger.a_log.info "statupweb : #{$statupweb_server_ip}:#{$statupweb_server_port}"
logger.a_log.info "ftp listening port : #{$ftp_server_port}"
logger.a_log.info "debugging : #{$debugging}"
logger.a_log.info "staging : #{$staging}"

include Tasking
#--------------------------------------------------------------------------------------------------------------------
# MAIN
#--------------------------------------------------------------------------------------------------------------------
EventMachine.run {
  Signal.trap("INT") { EventMachine.stop }
  Signal.trap("TERM") { EventMachine.stop }



  logger.a_log.info "scraper server is running"
  EventMachine.start_server "localhost", listening_port, TaskConnection, logger
}
logger.a_log.info "calendar server stopped"




















#!/usr/bin/env ruby -w
# encoding: UTF-8
require 'rufus-scheduler'
require 'yaml'
require File.dirname(__FILE__) + '/../lib/logging'
require File.dirname(__FILE__) + '/../model/communication'

PARAMETERS = File.dirname(__FILE__) + "/../parameter/" + File.basename(__FILE__, ".rb") + ".yml"
ENVIRONMENT= File.dirname(__FILE__) + "/../parameter/environment.yml"
$staging = "production"
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
  params = YAML::load(File.open(PARAMETERS), "r:UTF8")
  periodicity = params[$staging]["periodicity"] unless params[$staging]["periodicity"].nil?
  calendar_server_port = params[$staging]["calendar_server_port"] unless params[$staging]["calendar_server_port"].nil?
  debugging = params[$staging]["debugging"] unless params[$staging]["debugging"].nil?
rescue Exception => e
  STDERR << "parameters file #{PARAMETERS} : #{e.message}"
end

logger = Logging::Log.new(self, :staging => $staging, :id_file => File.basename(__FILE__, ".rb"), :debugging => debugging)

Logging::show_configuration
logger.a_log.info "parameters of timer server :"
logger.a_log.info "periodicity : #{periodicity}"
logger.a_log.info "calendar server port : #{calendar_server_port}"
logger.a_log.info "debugging : #{debugging}"
logger.a_log.info "staging : #{$staging}"

scheduler = Rufus::Scheduler.start_new
#declenche :
#toutes les heures de tous les jours de la semaine voir paramter file
scheduler.cron periodicity do
  begin
    logger.a_log.info "scheduler is running"
    now = Time.now #
    start_date = Date.new(now.year, now.month, now.day)
    hour = now.hour
    data = {"object" => "Event",
            "cmd" => "execute_all",
            "data" => {"date" => start_date, "hour" => hour}}

    logger.a_log.info "execute all events at date : #{start_date}, and hour #{hour}"
    logger.a_log.debug data
    logger.a_log.debug calendar_server_port
    Information.new(data).send_local(calendar_server_port)
  rescue Exception => e
    logger.a_log.fatal "cannot execute events at date : #{start_date}, and hour #{hour}"
    logger.a_log.debug e
  end

end

scheduler.join
logger.a_log.info "scheduler is stopping"
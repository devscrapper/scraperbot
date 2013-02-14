#!/usr/bin/env ruby -w
# encoding: UTF-8
require 'rufus-scheduler'
require 'yaml'
require File.dirname(__FILE__) + '/../lib/common'
require File.dirname(__FILE__) + '/../model/communication'

PARAMETERS = File.dirname(__FILE__) + "/../parameter/" + File.basename(__FILE__, ".rb") + ".yml"
$envir = "production"
#--------------------------------------------------------------------------------------------------------------------
# INPUT
#--------------------------------------------------------------------------------------------------------------------
ARGV.each { |arg|
  $envir = arg.split("=")[1] if arg.split("=")[0] == "--envir"
} if ARGV.size > 0
begin
  params = YAML::load(File.open(PARAMETERS), "r:UTF-8")
  periodicity = params[$envir]["periodicity"] unless params[$envir]["periodicity"].nil?
  calendar_server_port = params[$envir]["calendar_server_port"] unless params[$envir]["calendar_server_port"].nil?
rescue Exception => e
  Common.alert("parameters file #{PARAMETERS} is not found")
end

Common.information("parameters of timer server : ")
Common.information("periodicity : #{periodicity}")
Common.information("calendar server port : #{calendar_server_port}")

scheduler = Rufus::Scheduler.start_new
#declenche :
#toutes les heures de tous les jours de la semaine voir paramter file
scheduler.cron periodicity do
  begin
    now = Time.now #
    start_date = Date.new(now.year, now.month, now.day)
    hour = now.hour
    data = {"object" => "Event",
            "cmd" => "execute_all",
            "data" => {"date" => start_date, "hour" => hour}}

    Information.new(data).send_local(calendar_server_port)
  rescue Exception => e
    Common.alert("execute all cmd at time #{now} failed", __LINE__)
  end

end

scheduler.join
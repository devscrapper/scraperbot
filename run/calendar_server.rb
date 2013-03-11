#!/usr/bin/env ruby -w
# encoding: UTF-8
require 'rubygems' # if you use RubyGems
require 'eventmachine'
require 'json'
require 'logger'
require 'ice_cube'
require 'yaml'
require File.dirname(__FILE__) + '/../lib/logging'
require File.dirname(__FILE__) + '/../lib/common'
require File.dirname(__FILE__) + '/../model/event.rb'
require File.dirname(__FILE__) + '/../model/events.rb'

module CalendarServer
  include Common
  attr :events

  def receive_data param
    debug("data receive : #{param}")
    close_connection
    begin
      Thread.new { execute_task(YAML::load param) }
    rescue Exception => e
      alert("data receive #{param} : #{e.message}")
    end
  end

  def execute_task(data_receive)
    @events = Events.new() #TODO reporter la modif vers engine bot

    begin
      object = data_receive["object"]
      cmd = data_receive["cmd"]
      data_event = data_receive["data"]
      event = nil
      case object
        when Event.name
          event = Event.new(data_event["key"],
                            data_event["cmd"]) if !data_event["key"].nil? and !data_event["cmd"].nil?
        when Policy.name
          information("receive Policy for website #{data_event["label"]}")
          debug("details policy : #{data_event}")
          event = Policy.new(data_event).to_event
        when Website.name
          information("receive Website #{data_event["label"]}")
          debug("details Website : #{data_event}")
          event = Website.new(data_event).to_event
        else
          alert("object #{object} is not knowned")
      end
      case cmd
        when Event::EXECUTE_ALL
          if !data_event["date"].nil? and !data_event["hour"].nil?
            information("execute all jobs at date #{data_event["date"]}, hour #{data_event["hour"]}")
            Events.execute_all_at_time(data_event["date"], data_event["hour"], $scrape_server_port)
          else
            alert("execute all jobs at time failed because no time was set")
          end
        when Event::SAVE
          $sem.synchronize {
            event.each { |e|
              @events.delete(e) if @events.exist?(e)
              @events.add(e)
              information("save cmd #{e.cmd} for #{e.business["label"]}")
            }
            @events.save
          }
        when Event::DELETE
          $sem.synchronize {
            event.each { |e|
              p e
              @events.delete(e)
              information("delete cmd #{e.cmd} for #{e.key}")
            }
            @events.save
          }
        else
          alert("command #{cmd} is not known")
      end
    end
  end
end
                   #--------------------------------------------------------------------------------------------------------------------
                   # INIT
                   #--------------------------------------------------------------------------------------------------------------------
$sem = Mutex.new
$log_file = File.dirname(__FILE__) + "/../log/" + File.basename(__FILE__, ".rb") + ".log"
$data_file = File.dirname(__FILE__) + "/../data/" + File.basename(__FILE__, ".rb") + ".json"
PARAMETERS = File.dirname(__FILE__) + "/../parameter/" + File.basename(__FILE__, ".rb") + ".yml"
ENVIRONMENT= File.dirname(__FILE__) + "/../parameter/environment.yml"
listening_port = 9154
$scrape_server_port = 9151
$envir = "production"

#--------------------------------------------------------------------------------------------------------------------
# INPUT
#--------------------------------------------------------------------------------------------------------------------
begin
  environment = YAML::load(File.open(ENVIRONMENT), "r:UTF-8")
  $envir = environment["staging"] unless environment["staging"].nil?
rescue Exception => e
  Common.warning("loading parameter file #{ENVIRONMENT} failed : #{e.message}")
end
Common.information("environment : #{$envir}")
begin
  params = YAML::load(File.open(PARAMETERS), "r:UTF-8")
  listening_port = params[$envir]["listening_port"] unless params[$envir]["listening_port"].nil?
  $scrape_server_port = params[$envir]["scrape_server_port"] unless params[$envir]["scrape_server_port"].nil?
rescue Exception => e
  Common.alert("parameters file #{PARAMETERS} is not found")
end

Common.information("parameters of calendar server : ")
Common.information("listening port : #{listening_port}")
Common.information("scrape server port : #{$scrape_server_port}")
Common.information("environement : #{$envir}")
#--------------------------------------------------------------------------------------------------------------------
# MAIN
#--------------------------------------------------------------------------------------------------------------------

EventMachine.run {
  Signal.trap("INT") { EventMachine.stop }
  Signal.trap("TERM") { EventMachine.stop }
  Common.information("calendar server is starting")
  EventMachine.start_server "0.0.0.0", listening_port, CalendarServer
}
Common.information("calendar server stopped")



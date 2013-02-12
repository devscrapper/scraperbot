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
      #TODO on reste en thread tant que pas effet de bord et pas d'explosion du nombre de thread car plus rapide
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
      information ("processing request : object : #{object}, cmd : #{cmd}")
      p data_event
      case object
        when Event.name
          event = Event.new(data_event["key"],
                            data_event["cmd"]) if !data_event["key"].nil? and !data_event["cmd"].nil?
        when Policy.name
          event = Policy.new(data_event).to_event
        when Website.name
          event = Website.new(data_event).to_event
        else
          alert("object #{object} is not knowned")
      end
      case cmd
        when Event::EXECUTE_ALL
          if !data_event["time"].nil?
            time = Time._load(data_event["time"])
            information("execute all jobs at time #{time}")
            @events.execute_all_at_time(time)
          else
            alert("execute all jobs at time failed because no time was set")
          end
        when Event::EXECUTE_ONE
          information("execute one event #{event}")

          @events.execute_one(event, $scrape_server_port) if @events.exist?(event)

          information("event #{event} is not exist") unless @events.exist?(event)
        when Event::SAVE
          $sem.synchronize {
            information("save  #{object}   #{event.to_s}")
            if event.is_a?(Array)
                              p 1
              event.each { |e|
                p 2
                @events.delete(e) if @events.exist?(e)
                p 3
                @events.add(e)
                p 4
              }
            else
              p 3
              @events.delete(event) if @events.exist?(event)
              @events.add(event)
            end
              p 5
            @events.save
          }
        when Event::DELETE
          #TODO etudier le problème de la suppression d'une policy et de son impact sur la planification construite apres execution du building_objectives
          #TODO premier analyse : la répercution sur les objectives sera réalisée par la suppression de objective dans statupweb par declenchement par callback
          $sem.synchronize {
            information("delete  #{object}   #{event.to_s}")
            @events.delete(event)
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
listening_port = 9154
$scrape_server_port = 9151
$envir = "production"

#--------------------------------------------------------------------------------------------------------------------
# INPUT
#--------------------------------------------------------------------------------------------------------------------
ARGV.each { |arg|
  $envir = arg.split("=")[1] if arg.split("=")[0] == "--envir"
} if ARGV.size > 0
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
  EventMachine.start_server "localhost", listening_port, CalendarServer
}
Common.information("calendar server stopped")



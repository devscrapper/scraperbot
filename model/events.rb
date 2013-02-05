require 'rubygems' # if you use RubyGems
require 'json'
require File.dirname(__FILE__) + '/../model/event.rb'
require File.dirname(__FILE__) + '/../lib/common'

class Events
  EVENTS_FILE = File.dirname(__FILE__) + "/../data/" + File.basename(__FILE__, ".rb") + ".json"
  attr :events,
       :load_server_port

  def initialize(load_server_port)
    @load_server_port = load_server_port
    @events = Array.new
    begin
      JSON.parse(File.read(EVENTS_FILE)).each { |evt|
        #TODO VALIDER que les events qui sont passés dans le referentiel des evenements sont supprimé
        @events << Event.new(evt["key"], evt["cmd"], evt["periodicity"], evt["business"]) unless IceCube::Schedule.from_yaml(evt["periodicity"]).next_occurrence.nil?
      }
    rescue Exception => e
    end
  end

  def save()
    events_file = File.open(EVENTS_FILE, "w")
    events_file.sync = true
    events_file.write(JSON.pretty_generate(@events))
    events_file.close
  end

  def exist?(event)
    @events.each { |evt|
      return true if evt.key == event.key and evt.cmd == event.cmd
    } unless @events.nil?
    false
  end

  def add(event)
    event.each { |evt| @events << evt } if event.is_a?(Array)
    @events << event unless event.is_a?(Array)
  end

  def delete(events)
    @events.each_index { |i|
      events.each { |event|

        @events.delete_at(i) if @events[i].key == event.key and @events[i].cmd == event.cmd
      }
    }

  end

  def execute_one(event)
    @events.each { |evt|
      evt.execute(@load_server_port) if evt.key == event.key and evt.cmd == event.cmd
    } unless @events.nil?
  end

  def execute_all_at_time(time=Time.now)
    @events.each { |evt|
      schedule =IceCube::Schedule.from_yaml(evt.periodicity)
      if schedule.occurring_at?(time)
        begin
          evt.execute(@load_server_port, time)
        rescue Exception => e
          Common.alert("#{e.message}", __LINE__, __FILE__)
        end
      end

    }
  end

end




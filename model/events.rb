require 'rubygems' # if you use RubyGems
require 'json'
require File.dirname(__FILE__) + '/../model/event.rb'
require File.dirname(__FILE__) + '/../lib/common'

class Events
  EVENTS_FILE = File.dirname(__FILE__) + "/../data/" + File.basename(__FILE__, ".rb") + ".json"
  attr :events

  def self.execute_all_at_time(date, hour, load_server_port)
    #TODO reporter la modif vers engine bot
    Events.new.on_hour(date, hour).each { |evt|
      begin
        evt[0].execute(load_server_port)
      rescue Exception => e
        Common.alert("#{e.message}", __LINE__, __FILE__)
      end
    }
  end


  def initialize()
    #TODO reporter la modif vers engine bot
    @events = Array.new
    begin
      JSON.parse(File.read(EVENTS_FILE)).each { |evt|
        #TODO VALIDER que les events qui sont passés dans le referentiel des evenements sont supprimé
        @events << Event.new(evt["key"], evt["cmd"], evt["periodicity"], evt["business"]) unless IceCube::Schedule.from_yaml(evt["periodicity"]).next_occurrence.nil?
      }
    rescue Exception => e
    end
  end

  def [](i)
    @events[i]
  end

  def size
    @events.size
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

  def delete(event)
    @events.each_index { |i|
      @events.delete_at(i) if @events[i].key == event.key and @events[i].cmd == event.cmd
    }
  end


  def execute_one(event, load_server_port)
    #TODO reporter la modif vers engine bot
    @events.each { |evt|
      evt.execute(load_server_port) if evt.key == event.key and evt.cmd == event.cmd
    } unless @events.nil?
  end

  def display_cmd()
    i = 1
    @events.each { |evt|
      p "#{i} -> website : #{evt.business["label"]}, cmd #{evt.cmd}"
      i +=1
    }
  end

  def display_website()
    p "websites : "
    websites = {}
    @events.each { |evt| websites[evt.key["website_id"]] = evt.business["label"] unless evt.key["website_id"].nil? }
    websites.each_pair { |key, value| p "#{key} -> website : #{value}" }
  end

  def display_policy()
    p "policies : "
    policies = {}
    @events.each { |evt| policies[evt.key["policy_id"]] = evt.business["label"] unless evt.key["policy_id"].nil? }
    policies.each_pair { |key, value| p "#{key} -> website : #{value}" }
  end

  def on_hour(date, hour)
    start_time = Time.local(date.year, date.month, date.day, hour, 0, 0)
    on_period(start_time, start_time + IceCube::ONE_HOUR)
  end

  def on_day(date)
    start_time = Time.local(date.year, date.month, date.day)
    on_period(start_time, start_time + 23 * IceCube::ONE_HOUR)
  end

  def on_week(date)
    start_time = Time.local(date.year, date.month, date.day)
    on_period(start_time, start_time + IceCube::ONE_WEEK)
  end

  def on_period(start_time, end_time)
    selected_events = []
    @events.each { |evt|
      occurences = IceCube::Schedule.from_yaml(evt.periodicity).occurrences_between(start_time, end_time - IceCube::ONE_SECOND)  # end_time exclue
      selected_events << [evt, occurences] unless occurences.empty?
    }
    selected_events
  end

end




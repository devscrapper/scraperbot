require 'rubygems' # if you use RubyGems
require 'json'
require_relative 'event'
require_relative '../../lib/logging'

module Planning

  class Events
    class EventsException < StandardError
    end
    EVENTS_FILE = File.dirname(__FILE__) + "/../../data/" + File.basename(__FILE__, ".rb") + ".json"
    attr :events, :logger

    def initialize()
      @logger = Logging::Log.new(self, :staging => $staging, :debugging => $debugging)
      @events = Array.new
      begin
        JSON.parse(File.read(EVENTS_FILE)).each { |evt|
          #TODO VALIDER que les events qui sont passés dans le referentiel des evenements sont supprimé
          @events << Event.new(evt["key"], evt["cmd"], evt["periodicity"], evt["business"]) unless IceCube::Schedule.from_yaml(evt["periodicity"]).next_occurrence.nil?
        }
        @logger.an_event.info "repository events <#{EVENTS_FILE}> is loaded"
      rescue Exception => e
        @logger.an_event.warn "repository events is initialize empty"
        @logger.an_event.debug e
      ensure
        @events
      end
    end

    def execute_all_at_time(date, hour, load_server_port)
      raise ArgumentError, date if date.nil?
      raise ArgumentError, hour if hour.nil?
      raise ArgumentError, load_server_port if load_server_port.nil?

      on_hour(date, hour).each { |evt|
        begin
          evt[0].execute(load_server_port)
          @logger.an_event.info "ask execution event <#{evt[0].cmd}>"
        rescue Exception => e
          @logger.an_event.error "cannot ask execution event <#{evt[0].cmd}>"
          @logger.an_event.debug e
        end
      }
    end

    def save()
      begin
        events_file = File.open(EVENTS_FILE, "w")
        events_file.sync = true
        events_file.write(JSON.pretty_generate(@events))
        events_file.close
        @logger.an_event.info "repository events saved"
      rescue Exception => e
        @logger.an_event.warn "cannot save repository events"
        raise EventsException, e
      end
    end

    def [](i)
      @events[i]
    end

    def size
      @events.size
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
      @logger.an_event.info "save event #{event.cmd} for #{event.business["label"]} to repository"
    end

    def delete(event)
      @events.each_index { |i|
        @events.delete_at(i) if @events[i].key == event.key and @events[i].cmd == event.cmd
      }
      @logger.an_event.info "event #{event.cmd} for #{event.business["label"]} deleted from repository"
    end


    def execute_one(event, load_server_port)
      @events.each { |evt|
        evt.execute(load_server_port) if evt.key == event.key and evt.cmd == event.cmd
      } unless @events.nil?
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
        occurences = IceCube::Schedule.from_yaml(evt.periodicity).occurrences_between(start_time, end_time - IceCube::ONE_SECOND) # end_time exclue
        selected_events << [evt, occurences] unless occurences.empty?
      }
      selected_events
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
  end
end
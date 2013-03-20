require_relative 'events'
require_relative 'event'


module Planning

  class Calendar
    attr :events, :sem, :scrape_server_port

    def initialize(scrape_server_port)

      @logger = Logging::Log.new(self, :staging => $staging, :debugging => $debugging)
      @events = Events.new()
      @sem = Mutex.new
      @scrape_server_port = scrape_server_port
    end

    def execute_all(data_event)
      # exclusivement utiliser par le calendar_client.rb pour tester
      if !data_event["date"].nil? and !data_event["hour"].nil?
        @logger.an_event.info "ask execution all jobs at date #{data_event["date"]}, hour #{data_event["hour"]}"
        @events.execute_all_at_time(data_event["date"], data_event["hour"], @scrape_server_port)
      else
        @logger.an_event.error "cannot execute events because start time is not define"
        @logger.an_event.debug "date #{data_event["date"]}"
        @logger.an_event.debug "date #{data_event["hour"]}"
      end
    end

    def execute_all_at(date, hour)
      @logger.an_event.info "ask execution all jobs at date #{date}, hour #{hour}"
        @events.execute_all_at_time(date, hour, @scrape_server_port)
    end

    def save_object(object, data_event)
      begin
       require_relative "object2event/#{object.downcase}"
        events = eval(object).new(data_event).to_event
        @logger.an_event.debug "events #{events}"
        @sem.synchronize {
          events.each { |e|
            if @events.exist?(e)
              @events.delete(e)
            end
            @events.add(e)
          }
          @events.save
        }
      rescue Exception => e
        @logger.an_event.error "cannot save object #{object} into repository"
        @logger.an_event.debug e
      end

    end

    def delete_object(object, data_event)
      begin
        events = eval(object).new(data_event).to_event
        @logger.an_event.debug "events #{events}"
        @sem.synchronize {
          events.each { |e|
            @events.delete(e)
          }
          @events.save
        }
      rescue Exception => e
        @logger.an_event.error "cannot delete object #{object} from repository"
        @logger.an_event.debug e
      end
    end

    def wake_up(date, hour)
      begin
        data = {"object" => "Event",
                "cmd" => "execute_all",
                "data" => {"date" => date, "hour" => hour}}

        logger.a_log.info "wake up calendar at date : #{date}, and hour #{hour}"
        logger.a_log.debug data
        logger.a_log.debug calendar_server_port
        Information.new(data).send_local(calendar_server_port)
      rescue Exception => e
        logger.a_log.fatal "cannot execute events at date : #{date}, and hour #{hour}"
        logger.a_log.debug e
      end
    end
  end
end
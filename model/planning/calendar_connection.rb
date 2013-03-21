require 'rubygems' # if you use RubyGems
require 'eventmachine'

module Planning
  class CalendarConnection < EventMachine::Connection
    attr :calendar, # repository events
         :logger


    def initialize(logger, calendar)
      @calendar = calendar
      @logger = logger
    end

    def receive_data param
      @logger.an_event.debug "data receive <#{param}>"
      close_connection
      begin
        Thread.new {
          begin
            data = YAML::load param
            context = []
            object = data["object"]
            cmd = data["cmd"]
            data_cmd = data["data"]
            context << object << cmd
            context << data_cmd["date"] unless data_cmd["date"].nil?
            context << data_cmd["hour"] unless data_cmd["hour"].nil?

            @logger.ndc context
            @logger.an_event.debug "object <#{object}>"
            @logger.an_event.debug "cmd <#{cmd}>"
            @logger.an_event.debug "data cmd <#{data_cmd}>"
            @logger.an_event.debug "context <#{context}>"
            case cmd
              when Event::EXECUTE_ALL
                @calendar.execute_all(data_cmd)
              when Event::SAVE
                @logger.an_event.info "save events of the #{object} to repository"
                @calendar.save_object(object, data_cmd)
              when Event::DELETE
                @logger.an_event.info "delete events of the #{object} to repository"
                @calendar.delete_object(object, data_cmd)
              else
                @logger.an_event.error "cmd #{cmd} is unknown"
            end
          rescue Exception => e
            @logger.an_event.error "cannot execute cmd  <#{cmd}>"
            @logger.an_event.debug e
          end
        }
      rescue Exception => e
        @logger.an_event.error "cannot thread cmd"
        @logger.an_event.debug e
      end
    end


  end
end
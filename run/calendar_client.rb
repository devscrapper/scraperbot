require 'rubygems'
require 'eventmachine'
require File.dirname(__FILE__) + '/../model/communication.rb'
require File.dirname(__FILE__) + '/../lib/common.rb'
require File.dirname(__FILE__) + '/../model/event.rb'
require File.dirname(__FILE__) + '/../model/events.rb'

module MyKeyboardHandler
  attr :events,
       :calendar_server_port,
       :start_date,
       :start_hour,
       :period
  include EM::Protocols::LineText2

  def initialize(calendar_server_port)
    @calendar_server_port = calendar_server_port
    @events = Events.new()
    @start_date = Date.today
    @start_hour = 0
    @period = "day"
    display
  end

  def receive_line data
    puts "Action : #{data}"
    case data.split[0]
      when "x"
        EM.stop
      when "r"
        @events = Events.new()
      when "d"
        case data.split[1]
          when "a"
            p "delete all objects"
            (0..@events.size - 1).each { |event|
              query = {"cmd" => "delete", "object" => "Website", "data" => {"website_id" => @events[event].key["website_id"].to_i}} unless @events[event].key["website_id"].nil?
              query = {"cmd" => "delete", "object" => "Policy", "data" => {"policy_id" => @events[event].key["policy_id"].to_i}} unless @events[event].key["policy_id"].nil?
              p "delete cmd <#{@events[event].cmd}> for #{@events[event].business["label"]}"
              Information.new(query).send_local(@calendar_server_port)
            }
          when "w"
            data[4..data.size - 0].split.each { |website_id|
              query = {"cmd" => "delete", "object" => "Website", "data" => {"website_id" => website_id.to_i}}
              Information.new(query).send_local(@calendar_server_port)
            }
          when "p"
            data[4..data.size - 0].split.each { |policy_id|
              query = {"cmd" => "delete", "object" => "Policy", "data" => {"policy_id" => policy_id.to_i}}
              p query
              Information.new(query).send_local(@calendar_server_port)
            }
          else
            p "object <#{data.split[1]}> unknown"
        end
        @events = Events.new()
      when "p"
        case data.split[1]
          when "hour", "day", "week"
            @period = data.split[1]
          else
            p "period <#{data.split[1]}> unknown"
        end
      when "t"
        case data.split[1]
          when "today"
            @start_date = Date.today
          else
            begin
              @start_date = Date.parse(data.split[1])
            rescue Exception => e
              p "<#{data.split[1]}> #{e.message}"
            end
        end
      when "h"
        case data.split[1]
          when "now"
            @start_hour = Time.now.hour
          else

            @start_hour = data.split[1].to_i if data.split[1].to_i <= 23 and data.split[1].to_i >= 0
            p "bad hour <#{data.split[1]}>" unless  data.split[1].to_i <= 23 and data.split[1].to_i >= 0

        end
      when "e"
        p "execute cmds of period #{@period}"
        nb_hours = 1 if @period == "hour"
        nb_hours = 24 if @period == "day"
        nb_hours = 0 if @period == "week"
        nb_hours.times { |hour|
          hour = @start_hour if @period == "hour"
          data = {"object" => "Event",
                  "cmd" => "execute_all",
                  "data" => {"date" => @start_date, "hour" => hour}}

          Information.new(data).send_local(@calendar_server_port)
        }
      when "h"
        now = Time.local(Date.today.year,
                         Date.today.month,
                         Date.today.day,
                         data.split[1].to_i, 0, 0)

        data = {"object" => "Event",
                "cmd" => "execute_all",
                "data" => {"time" => now._dump.force_encoding("UTF-8")}}

        Information.new(data).send_local(@calendar_server_port)
      else
        p "action <#{data}> unknown"
    end
    display
  end

  def display_events()
    p "events during a #{@period} from #{@start_date}:#{@start_hour}H : " if @period == "hour"
    p "events during a #{@period} from #{@start_date} : " unless @period == "hour"
    events = @events.on_hour(@start_date, @start_hour) if @period == "hour"
    events = @events.on_day(@start_date) if @period == "day"
    events = @events.on_week(@start_date) if @period == "week"
    events.each { |evt| p "#{evt[0].cmd} - #{evt[0].business["label"]} - #{evt[1]}"
    }
  end

  def display()
    p "**************************************************************************************************************"
    @events.display_website
    p "--------------------------------------------------------------------------------------------------------------"
    @events.display_policy
    p "--------------------------------------------------------------------------------------------------------------"
    p "d [w|p] 1 2 ... -> delete many object[website|policy]"
    p "d a -> delete all objects"
    p "**************************************************************************************************************"
    display_events
    p "--------------------------------------------------------------------------------------------------------------"
    p "p [hour|day|week]-> change period"
    p "t [today| yyyy-mm-dd -> change current date"
    p "h [now| hh -> change current hour"
    p "e -> execute all cmds of period (only hour|day)"
    p "**************************************************************************************************************"
    p "x -> exit"
    p "r -> reload objects"
    p "**************************************************************************************************************"
  end
end

calendar_server_port = 9154
$envir = "production"
PARAMETERS = File.dirname(__FILE__) + "/../parameter/" + File.basename(__FILE__, ".rb") + ".yml"
#--------------------------------------------------------------------------------------------------------------------
# INPUT
#--------------------------------------------------------------------------------------------------------------------
ARGV.each { |arg|
  $envir = arg.split("=")[1] if arg.split("=")[0] == "envir"
} if ARGV.size > 0
begin
  params = YAML::load(File.open(PARAMETERS), "r:UTF-8")
  calendar_server_port = params[$envir]["calendar_server_port"] unless params[$envir]["calendar_server_port"].nil?
rescue Exception => e
  Common.alert("parameters file #{PARAMETERS} is not found")
end

Common.information("parameters of client calendar : ")
Common.information("scrape server port : #{calendar_server_port}")
Common.information("environement : #{$envir}")
EM.run {
  EM.open_keyboard MyKeyboardHandler, calendar_server_port
}
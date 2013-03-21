require 'rubygems'
require 'eventmachine'
require_relative '../model/planning/event'
require_relative '../model/planning/events'


module MyKeyboardHandler
  attr :events
  include EM::Protocols::LineText2
  include Planning
  def initialize()

    @events = Events.new()
    display
  end

  def receive_line data
    puts "Action : #{data}"
    case data
      when "x"
        EM.stop
      when "r"
        @events = Events.new()
      else
        data.split.each { |id|
          if !@events[id.to_i - 1].nil?
            evt = @events[id.to_i - 1]
            p "execute #{evt.cmd} for #{evt.key["label"]}"
            @events.execute_one(Event.new(evt.key, evt.cmd), @scrape_server_port)
          else
            p "action <#{id}> unknown"
          end


        }
    end
    display
  end

  def display()
    p "--------------------------------------------------------------------------------------------------------------"
    @events.display_cmd
    p "--------------------------------------------------------------------------------------------------------------"
    p "x -> exit"
    p "r -> reload events"
    p "1 2 ... -> execute many cmd"
    p "--------------------------------------------------------------------------------------------------------------"
  end
end


$staging = "production"
PARAMETERS = File.dirname(__FILE__) + "/../parameter/" + File.basename(__FILE__, ".rb") + ".yml"
ENVIRONMENT= File.dirname(__FILE__) + "/../parameter/environment.yml"
#--------------------------------------------------------------------------------------------------------------------
# INPUT
#--------------------------------------------------------------------------------------------------------------------
begin
  environment = YAML::load(File.open(ENVIRONMENT), "r:UTF-8")
  $staging = environment["staging"] unless environment["staging"].nil?
rescue Exception => e
  p e
end
p "environment : #{$staging}"
begin
  params = YAML::load(File.open(PARAMETERS), "r:UTF-8")
  $debugging = params[$staging]["debugging"] unless params[$staging]["debugging"].nil?
rescue Exception => e
  p "parameters file #{PARAMETERS} is not found"
end

p "parameters of client scraper : "
p "debugging : #{$debugging}"

EM.run {
  EM.open_keyboard MyKeyboardHandler
}
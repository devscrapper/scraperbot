require 'rubygems'
require 'eventmachine'
require File.dirname(__FILE__) + '/../model/communication.rb'
require File.dirname(__FILE__) + '/../lib/common.rb'
require File.dirname(__FILE__) + '/../model/event.rb'
require File.dirname(__FILE__) + '/../model/events.rb'

module MyKeyboardHandler
  attr :events,
      :scrape_server_port
  include EM::Protocols::LineText2

  def initialize(scrape_server_port)

    @scrape_server_port = scrape_server_port
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
        evt = @events[data.to_i - 1]
        p "execute #{evt.cmd} for #{evt.key["label"]}"

        @events.execute_one(Event.new(evt.key, evt.cmd), @scrape_server_port)
    end
    display
  end

  def display()
    @events.display
    p "x -> exit"
    p "r -> reload events"
  end
end

scrape_server_port = 9151
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
  scrape_server_port = params[$envir]["scrape_server_port"] unless params[$envir]["scrape_server_port"].nil?
rescue Exception => e
  Common.alert("parameters file #{PARAMETERS} is not found")
end

Common.information("parameters of client calendar : ")
Common.information("scrape server port : #{scrape_server_port}")
Common.information("environement : #{$envir}")
EM.run {
  EM.open_keyboard MyKeyboardHandler , scrape_server_port
}
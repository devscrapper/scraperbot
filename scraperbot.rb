require 'rubygems'
require 'eventmachine'
require 'em-http'
require 'json'
require 'json/ext'
require 'date'
require  File.dirname(__FILE__) + '/model/website.rb'


module ScraperbotServer

  def initialize()

  end

  def post_init
    puts "-- someone connected to the echo server! #{EM.connection_count} "
  end

  def receive_data param
   data =  JSON.parse param
    case data["cmd"]
      when "website"
        p "Scrapping Website #{data["url"]}"
        w = Website.new(data["url"])
        w.scrape() if data["count_page"].nil?
        w.scrape(data["count_page"]) unless data["count_page"].nil?
        close_connection
      when "exit"
        EventMachine.stop
      else

    end
  end

  def unbind
    puts "-- someone disconnected #{EM.connection_count} from the echo server! #"
  end
end


EventMachine.run {
  Signal.trap("INT") { EventMachine.stop }
  Signal.trap("TERM") { EventMachine.stop }
  EventMachine.start_server "127.0.0.1", 8081, ScraperbotServer
}
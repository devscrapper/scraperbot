require 'rubygems'
require 'eventmachine'
require 'em-http'
require 'json'
require 'json/ext'
require 'date'
require File.dirname(__FILE__) + '/../model/website.rb'
require File.dirname(__FILE__) + '/../model/traffic_source.rb'
require File.dirname(__FILE__) + '/../lib/logging'
require 'logger'

module ScraperbotServer
  attr :authentification_server_port,
       :load_server_ip,
       :load_server_port,
       :output_file_size


  def initialize(authentification_server_port, load_server_ip, load_server_port, output_file_size)
    @authentification_server_port = authentification_server_port
    @load_server_ip = load_server_ip
    @load_server_port = load_server_port
    @output_file_size = output_file_size
  end

  def post_init
  end


  def receive_data param
    data = JSON.parse param
    who = data["who"]
    port, ip = Socket.unpack_sockaddr_in(get_peername)
    case data["cmd"]
      when "send_me_all_files"
        Website.new(self, data["label"]).send_all_files()
        Traffic_source.new(self, data["label"]).send_all_files()
        p "Send all Website files to #{who}(#{ip}:#{port})"
        Logging.send($log_file, Logger::INFO, "Send all Website files to #{who}(#{ip}:#{port})")
      when "website"
        options = Hash.new
        p "Scrapping Website #{data["label"]} for #{who}(#{ip}:#{port})"
        Logging.send($log_file, Logger::INFO, "Scrapping Website #{data["label"]} for #{who}(#{ip}:#{port})")
        w = Website.new(self, data["label"], data["url"])
        options["count_page"] = data["count_page"] unless data["count_page"].nil?
        options["schemes"] = data["schemes"] unless data["schemes"].nil?
        options["type"] = data["type"] unless data["type"].nil?
        w.scrape(options)
        close_connection
      when "traffic_source"
        options = Hash.new
        p "Scrapping Traffic_source #{data["label"]} for #{who}(#{ip}:#{port})"
        Logging.send($log_file, Logger::INFO, "Scrapping Traffic_source #{data["label"]} for #{who}(#{ip}:#{port})")
        w = Traffic_source.new(self, data["label"], data["profil_id_ga"])
        options["start_date"] = data["start_date"] unless data["start_date"].nil?
        options["end_date"] = data["end_date"] unless data["end_date"].nil?
        w.scrape(options)
        close_connection
      when "exit"
        EventMachine.stop
      else
    end
  end

  def unbind
  end
end


#--------------------------------------------------------------------------------------------------------------------
# INIT
#--------------------------------------------------------------------------------------------------------------------
$log_file = File.dirname(__FILE__) + "/../log/" + File.basename(__FILE__, ".rb") + ".log"
# ftp_server et scraper server sont sur la même machine en raison du repertoire de partagé des fichiers
# scraper_server le rempli, et ftp_server le publie et le vide.
listening_port = 9003 # port d'ecoute du load_server
objects="website,traffic_source" # liste des objets que gere le scraper_server
authentification_server_port = 9001
calendar_server_port=9005
calendar_server_ip="localhost"
load_server_ip = "localhost"
load_server_port = 9002
output_file_size = 1000000


#--------------------------------------------------------------------------------------------------------------------
# INPUT
#--------------------------------------------------------------------------------------------------------------------
ARGV.each { |arg|
  listening_port = arg.split("=")[1] if arg.split("=")[0] == "--port"
  objects = arg.split("=")[1] if arg.split("=")[0] == "--objects"
  authentification_server_port = arg.split("=")[1] if arg.split("=")[0] == "--authentification_server_port"
  calendar_server_port = arg.split("=")[1] if arg.split("=")[0] == "--calendar_server_port"
  calendar_server_ip = arg.split("=")[1] if arg.split("=")[0] == "--calendar_server_ip"
  load_server_ip = arg.split("=")[1] if arg.split("=")[0] == "--load_server_ip"
  load_server_port = arg.split("=")[1] if arg.split("=")[0] == "--load_server_port"
  output_file_size = arg.split("=")[1] if arg.split("=")[0] == "--output_file_size"
} if ARGV.size > 0


Logging.send($log_file, Logger::INFO, "parameters of load server : ")
Logging.send($log_file, Logger::INFO, "listening port : #{listening_port}")
Logging.send($log_file, Logger::INFO, "objects : #{objects}")
Logging.send($log_file, Logger::INFO, "authentification server port : #{authentification_server_port}")
Logging.send($log_file, Logger::INFO, "calendar server port : #{calendar_server_port}")
Logging.send($log_file, Logger::INFO, "calendar server ip : #{calendar_server_ip}")
Logging.send($log_file, Logger::INFO, "load server ip : #{load_server_ip}")
Logging.send($log_file, Logger::INFO, "load server port : #{load_server_port}")
Logging.send($log_file, Logger::INFO, "output file size : #{output_file_size}")


#--------------------------------------------------------------------------------------------------------------------
# MAIN
#--------------------------------------------------------------------------------------------------------------------
# informe le calendar_server des objets que le scraper_server geres
begin
  s = TCPSocket.new calendar_server_ip, calendar_server_port
  s.puts JSON.generate({"what" => "calendar", "cmd" => "management", "objects" => objects, "port" => listening_port})
  s.close
  Logging.send($log_file, Logger::INFO, "push to calendar_server (#{calendar_server_ip}:#{calendar_server_port}), objects (#{objects}) manage  by scraper_server (#{listening_port})")
  p "push to calendar_server (#{calendar_server_ip}:#{calendar_server_port}), objects (#{objects}) manage  by scraper_server"
rescue Exception => e
  Logging.send($log_file, Logger::WARN, "connexion to calendar_server (#{calendar_server_ip}:#{calendar_server_port}) failed : #{e.message}")
  p "connexion to calendar_server (#{calendar_server_ip}:#{calendar_server_port}) failed => cannot be managed by calendar_server"
end

# démarrage du server
EventMachine.run {
  Signal.trap("INT") { EventMachine.stop }
  Signal.trap("TERM") { EventMachine.stop }
  EventMachine.start_server "0.0.0.0", listening_port, ScraperbotServer, authentification_server_port, load_server_ip, load_server_port, output_file_size
}


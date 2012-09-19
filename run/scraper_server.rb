require 'rubygems'
require 'eventmachine'
require 'em-http'
require 'json'
require 'json/ext'
require 'date'
require  File.dirname(__FILE__) + '/../model/website.rb'
require File.dirname(__FILE__) + '/../lib/logging'
require 'logger'

module ScraperbotServer
  attr :authentification_server_port,
       :load_server_ip,
       :load_server_port,
       :output_file_size


  def initialize(authentification_server_port,load_server_ip, load_server_port, output_file_size)
    @authentification_server_port = authentification_server_port
    @load_server_ip = load_server_ip
    @load_server_port = load_server_port
    @output_file_size = output_file_size
  end

  def post_init
  end

  def receive_data param
   data =  JSON.parse param
   who = data["who"]
   port, ip = Socket.unpack_sockaddr_in(get_peername)
    case data["cmd"]
      when "send_me_all_files"
        Website.new(self).send_all_files()
        p "Send all Website files to #{who}(#{ip}:#{port})"
        Logging.send($log_file, Logger::INFO, "Send all Website files to #{who}(#{ip}:#{port})")
      when "website"
        options = Hash.new
        p "Scrapping Website #{data["url"]} for #{who}(#{ip}:#{port})"
        Logging.send($log_file, Logger::INFO, "Scrapping Website #{data["url"]} for #{who}(#{ip}:#{port})")
        w = Website.new(self,data["url"])
        options["count_page"] = data["count_page"] unless data["count_page"].nil?
        options["schemes"] = data["schemes"] unless data["schemes"].nil?
        options["type"] = data["type"] unless data["type"].nil?
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
authentification_server_port = 9001
load_server_ip = "localhost"
load_server_port = 9002
output_file_size = 1000000


#--------------------------------------------------------------------------------------------------------------------
# INPUT
#--------------------------------------------------------------------------------------------------------------------
ARGV.each { |arg|
  listening_port = arg.split("=")[1] if arg.split("=")[0] == "--port"
  authentification_server_port  = arg.split("=")[1] if arg.split("=")[0] == "--authentification_server_port"
  load_server_ip  = arg.split("=")[1] if arg.split("=")[0] == "--load_server_ip"
  load_server_port  = arg.split("=")[1] if arg.split("=")[0] == "--load_server_port"
  output_file_size  = arg.split("=")[1] if arg.split("=")[0] == "--output_file_size"
} if ARGV.size > 0



Logging.send($log_file, Logger::INFO, "parameters of load server : ")
Logging.send($log_file, Logger::INFO, "listening port : #{listening_port}")
Logging.send($log_file, Logger::INFO, "authentification server port : #{authentification_server_port}")
Logging.send($log_file, Logger::INFO, "load server ip : #{load_server_ip}")
Logging.send($log_file, Logger::INFO, "load server port : #{load_server_port}")
Logging.send($log_file, Logger::INFO, "output file size : #{output_file_size}")



#--------------------------------------------------------------------------------------------------------------------
# MAIN
#--------------------------------------------------------------------------------------------------------------------
# démarrage du server
EventMachine.run {
  Signal.trap("INT") { EventMachine.stop }
  Signal.trap("TERM") { EventMachine.stop }
  EventMachine.start_server "0.0.0.0", listening_port, ScraperbotServer, authentification_server_port, load_server_ip, load_server_port, output_file_size
}


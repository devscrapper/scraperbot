require 'rubygems'
require 'eventmachine'
require 'json'
require 'json/ext'
require 'digest/sha2'
require 'yaml'
require File.dirname(__FILE__) + '/../lib/logging'
require 'logger'
require 'net/ftp'
require File.dirname(__FILE__) + '/../lib/scraping_google_analytics'
require File.dirname(__FILE__) + '/../lib/scraping_website'
require File.dirname(__FILE__) + '/../lib/common'
require File.dirname(__FILE__) + '/../model/google_analytics'

module ScrapeServer
  include Common
  INPUT = File.dirname(__FILE__) + "/../input/"
  TMP = File.dirname(__FILE__) + "/../tmp/"


  def receive_data param
    debug ("data receive : #{param}")
    close_connection
    begin
      #TODO on reste en thread tant que pas effet de bord et pas d'explosion du nombre de thread car plus rapide
      Thread.new { execute_task(YAML::load(param)) }
    rescue Exception => e
      warning("data receive #{param} : #{e.message}")
    end
  end

  def execute_task(data)
    task = data["cmd"]
    case task
      when "Scraping_behaviour"
        label = data["label"]
        date_building = data["date_building"]
        profil_id_ga = data["data"]["profil_id_ga"]
        p label
        p date_building
        p profil_id_ga
        Scraping_google_analytics.Scraping_behaviour(label, date_building, profil_id_ga)
        information("scraping behaviour")

      when "Scraping_hourly_daily_distribution"
        label = data["label"]
        date_building = data["date_building"]
        profil_id_ga = data["data"]["profil_id_ga"]
        Scraping_google_analytics.Scraping_hourly_daily_distribution(label, date_building, profil_id_ga)
        Information("scraping hourly daily distribution")

      when "Scraping_traffic_source_landing_page"
        label = data["label"]
        date_building = data["date_building"]
        profil_id_ga = data["data"]["profil_id_ga"]
        Scraping_google_analytics.Scraping_traffic_source_landing_page(label, date_building, profil_id_ga)
        Information("scraping traffic source landing page")

      when "Scraping_device_platform_resolution"
        label = data["label"]
        date_building = data["date_building"]
        profil_id_ga = data["data"]["profil_id_ga"]
        p label
        p date_building
        p profil_id_ga
        Scraping_google_analytics.Scraping_device_platform_resolution(label, date_building, profil_id_ga)
        Information("scraping device platform resolution")

      when "Scraping_device_platform_plugin"
        label = data["label"]
        date_building = data["date_building"]
        profil_id_ga = data["data"]["profil_id_ga"]
        Scraping_google_analytics.Scraping_device_platform_plugin(label, date_building, profil_id_ga)
        Information("scraping device platform plugin")

      when "Scraping_website"
        label = data["label"]
        date_building = data["date_building"]
        url_root = data["url_root"]
        count_page = data["count_page"]
        schemes = data["schemes"]
        types = data["types"]
        Scraping_website.Scraping_pages(label, date_building, url_root, count_page, schemes, types)
        Information("scraping website")

      when "exit"
        EventMachine.stop
      else
        port, ip = Socket.unpack_sockaddr_in(get_peername)
        alert("unknown action : #{data["cmd"]} from  #{ip}:#{port}")
    end
  end

end


#--------------------------------------------------------------------------------------------------------------------
# INIT
#--------------------------------------------------------------------------------------------------------------------
$log_file = File.dirname(__FILE__) + "/../log/" + File.basename(__FILE__, ".rb") + ".log"
PARAMETERS = File.dirname(__FILE__) + "/../parameter/" + File.basename(__FILE__, ".rb") + ".yml"


$listening_port = 9151 # port d'ecoute du scrape_server
$authentification_server_port = 9153
$calendar_server_port=9154
$ftp_server_port = 9152
$input_flows_server_ip = "localhost"
$input_flows_server_port = 9101
$statupweb_server_ip = "localhost"
$statupweb_server_port = 3000
$envir = "production"

#--------------------------------------------------------------------------------------------------------------------
# INPUT
#--------------------------------------------------------------------------------------------------------------------
ARGV.each { |arg|
  $envir = arg.split("=")[1] if arg.split("=")[0] == "--envir"
} if ARGV.size > 0

begin
  params = YAML::load(File.open(PARAMETERS), "r:UTF-8")
  $listening_port = params[$envir]["listening_port"] unless params[$envir]["listening_port"].nil?
  $calendar_server_port = params[$envir]["calendar_server_port"] unless params[$envir]["calendar_server_port"].nil?
  $authentification_server_port = params[$envir]["authentification_server_port"] unless params[$envir]["authentification_server_port"].nil?
  $input_flows_server_ip = params[$envir]["input_flows_server_ip"] unless params[$envir]["input_flows_server_ip"].nil?
  $input_flows_server_port = params[$envir]["input_flows_server_port"] unless params[$envir]["input_flows_server_port"].nil?
  $statupweb_server_ip = params[$envir]["statupweb_server_ip"] unless params[$envir]["statupweb_server_ip"].nil?
  $statupweb_server_port = params[$envir]["statupweb_server_port"] unless params[$envir]["statupweb_server_port"].nil?
  $ftp_server_port = params[$envir]["ftp_server_port"] unless params[$envir]["ftp_server_port"].nil?
rescue Exception => e
  p e.message
  Logging.send($log_file, Logger::INFO, "parameters file #{PARAMETERS} is not found")
end

Common.information("parameters of scrape server : ")
Common.information("listening port : #{$listening_port}")
Common.information("calendar server port : #{$calendar_server_port}")
Common.information("authentification server port : #{$authentification_server_port}")
Common.information("ftp_server_port : #{$ftp_server_port}")
Common.information("input_flows server ip : #{$input_flows_server_ip}")
Common.information("input_flows server port : #{$input_flows_server_port}")
Common.information("statupweb server ip : #{$statupweb_server_ip}")
Common.information("statupweb server port : #{$statupweb_server_port}")



#--------------------------------------------------------------------------------------------------------------------
# MAIN
#--------------------------------------------------------------------------------------------------------------------
Common.information("environement : #{$envir}")
# démarrage du server


EventMachine.run {
  Signal.trap("INT") { EventMachine.stop }
  Signal.trap("TERM") { EventMachine.stop }
  Common.information ("scrape server is starting")
  EventMachine.start_server "localhost", $listening_port, ScrapeServer
}
Common.information ("scrape server stopped")

#--------------------------------------------------------------------------------------------------------------------
# END
#--------------------------------------------------------------------------------------------------------------------

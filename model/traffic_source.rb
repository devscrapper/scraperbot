require 'rubygems'
require 'json'
require 'json/ext'
require 'eventmachine'
require File.dirname(__FILE__) + '/../lib/logging'
require File.dirname(__FILE__) + '/scraping.rb'
require File.dirname(__FILE__) + '/../lib/exchange_file'
require File.dirname(__FILE__) + '/../lib/google_analytics'
require 'logger'
# ---------------------------------------------------------------------------------------------------------------------
# TODO :
# rediger les commentaires pour les input
# ---------------------------------------------------------------------------------------------------------------------
class Traffic_source < Scraping
  include Exchange_file
  include Google_analytics
  EOF_TRAFFIC_SOURCE = "|"
  SEPARATOR = ";"

  # Input
  attr :today, #date du jour du premier volume => eviter que les fichiers n'aient pas la meme date
       :push_file_spawn,
       :profil_id_ga


  def initialize(connection, label=nil, profil_id_ga=nil)
    # profil_id_ga = nil si et seulement si on renvoit tous les fichiers de l'OUTPUT préfixé par le nom de la classe
    super(connection, label)
    @profil_id_ga = profil_id_ga
  end

  def scrape(options)
    @today = Date.today

    # delete les fichiers existants : on ne conserve qu'un resultat de scrapping par website
    delete_all_output_files

    # creation du premier volume de données et du fichier des erreurs
    new_volume_output_file

    # comportement par defaut du scraping :
    # start_date = end_date sont le jour précédent
    @start_date = Date.parse(options["start_date"]) unless options["start_date"].nil?
    @start_date = Date.today.prev_day(1) if  options["start_date"].nil?
    @end_date = Date.parse(options["end_date"]) unless options["end_date"].nil?
    @end_date = Date.today.prev_day(1) if  options["end_date"].nil?

    Logging.send(@log_file, Logger::DEBUG, "scrapping traffic_sourece options : ")
    Logging.send(@log_file, Logger::DEBUG, "start_date : #{@start_date}")
    Logging.send(@log_file, Logger::DEBUG, "end_date : #{@end_date}")

    Logging.send(@log_file, Logger::INFO, "scrapping traffic_source of #{@label} is running ")
    @dimensions = "ga:hostname,ga:landingPagePath,ga:medium,ga:keyword,ga:referralPath,ga:source"
    @metrics = "ga:entrances"
    begin
      connect_to_ga(@profil_id_ga)

      execute().each { |traffic_source|
        row = "#{traffic_source["hostname"]}#{SEPARATOR}#{traffic_source["landingPagePath"]}#{SEPARATOR}#{traffic_source["medium"]}#{SEPARATOR}#{traffic_source["keyword"]}#{SEPARATOR}#{traffic_source["referralPath"]}#{SEPARATOR}#{traffic_source["traffic_source"]}#{EOF_TRAFFIC_SOURCE}"
        output(row)
      }
      @f.close
      Logging.send(@log_file, Logger::DEBUG, "fetch traffic_source for #{self.class.name}:#{@label} is ok")
    rescue Exception => e
      p "fetch traffic_source for #{self.class.name}:#{@label}, failed"
      Logging.send(@log_file, Logger::ERROR, "fetch traffic_source for #{self.class.name}:#{@label} failed : #{e.message}")
    end
  end

  def output(source)
    @f.write(source.to_s)
    if  @f.size > @connection.output_file_size.to_i
      # informer Load_server qu'il peut telecharger le fichier
      @push_file_spawn.notify File.basename(@f)
      @f.close
      new_volume_output_file
    end
  end


end


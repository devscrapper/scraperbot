#!/usr/bin/env ruby -w
# encoding: UTF-8

require 'ruby-progressbar'
require File.dirname(__FILE__) + '/../lib/common'
require File.dirname(__FILE__) + '/../lib/logging'
require File.dirname(__FILE__) + '/../model/google_analytics'
require File.dirname(__FILE__) + '/../model/flow'
require File.dirname(__FILE__) + '/../model/authentification'

#------------------------------------------------------------------------------------------
# Pre requis gem
#------------------------------------------------------------------------------------------


module Scraping_google_analytics
  class Scraping_google_analyticsException < StandardError;
  end
  include Common
#------------------------------------------------------------------------------------------
# Globals variables
#------------------------------------------------------------------------------------------

  TEST = File.dirname(__FILE__) + "/../test/"
  OUTPUT = File.dirname(__FILE__) + "/../output/"

  SEPARATOR="%SEP%"
  EOFLINE="%EOFL%"
  SEPARATOR2=";"
  SEPARATOR3="!"
  SEPARATOR4="|"
  SEPARATOR5=","
  SEPARATOR6="_"
  EOFLINE2 ="\n"
  LOG_FILE = File.dirname(__FILE__) + "/../log/" + File.basename(__FILE__, ".rb") + ".log"

#inputs

# local


#--------------------------------------------------------------------------------------------------------------
# Scraping_hourly_daily_distribution
#--------------------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------------------


  def Scraping_hourly_daily_distribution(label, date, profil_id_ga)
    Common.information("Scraping hourly daily distribution for #{label} for #{date} is starting")
    output_flow = nil
    begin
      options={}
      options["sort"] = "date"
      options["max-results"] = 24 * 7

      output_flow = scraping("scraping-hourly-daily-distribution",
                             label,
                             date,
                             profil_id_ga,
                             "day,hour,date",
                             "visits",
                             DateTime.now.prev_day(7).strftime("%Y-%m-%d"),
                             DateTime.now.prev_day(1).strftime("%Y-%m-%d"),
                             options)
    rescue Exception => e
      Common.alert("Scraping hourly_daily_distribution for #{label} failed #{e.message}")
    end
    # pousser le flow vers input_flow_server sur engine_bot
    output_flow.push($authentification_server_port,
                     $input_flows_server_ip,
                     $input_flows_server_port,
                     $ftp_server_port)

    #TODO mettre à jour la date de scraping hourly daily distribution
    # maj date de scraping sur webstatup
    Common.information("Scraping hourly daily distribution for #{label} is over")
  end

#--------------------------------------------------------------------------------------------------------------
# Scraping_behaviour
#--------------------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------------------
  def Scraping_behaviour(label, date, profil_id_ga)
    Common.information("Scraping behaviour for #{label} for #{date} is starting")
    output_flow = nil
    begin
      options={}
      options["sort"] = "date"
      options["max-results"] = 7
      output_flow = scraping("scraping-behaviour",
                             label,
                             date,
                             profil_id_ga,
                             "day,date",
                             "percentNewVisits,visitBounceRate,avgTimeOnSite,pageviewsPerVisit,visits",
                             DateTime.now.prev_day(7).strftime("%Y-%m-%d"),
                             DateTime.now.prev_day(1).strftime("%Y-%m-%d"),
                             options)
    rescue Exception => e
      Common.alert("Scraping behaviour for #{label} failed : #{e.message}")
    end

    # pousser le flow vers input_flow_server sur engine_bot
    output_flow.push($authentification_server_port,
                     $input_flows_server_ip,
                     $input_flows_server_port,
                     $ftp_server_port)

    #TODO mettre à jour la date de scraping behaviour
    Common.information("Scraping behaviour for #{label} is over")
  end

#--------------------------------------------------------------------------------------------------------------
# private
#--------------------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------------------


  def to_file(data, output_flow)
    #TODO valider la sauvegarde dans un fichier
    data.each { |e| output_flow.write(e) }
  end

  def scraping(type_flow, label, date, profil_id_ga, dimensions, metrics, startDate, endDate, options)
    Logging.send(LOG_FILE, Logger::DEBUG, "scraping to google analytics : ")
    Logging.send(LOG_FILE, Logger::DEBUG, "type file : #{type_flow} ")
    Logging.send(LOG_FILE, Logger::DEBUG, "label : #{label} ")
    Logging.send(LOG_FILE, Logger::DEBUG, "date : #{date}")
    Logging.send(LOG_FILE, Logger::DEBUG, "profil_id_ga : #{profil_id_ga}")
    Logging.send(LOG_FILE, Logger::DEBUG, "dimensions : #{dimensions}")
    Logging.send(LOG_FILE, Logger::DEBUG, "metrics : #{metrics}")
    Logging.send(LOG_FILE, Logger::DEBUG, "startDate : #{startDate}")
    Logging.send(LOG_FILE, Logger::DEBUG, "endDate : #{endDate}")
    Logging.send(LOG_FILE, Logger::DEBUG, "options : #{options}")

    output_flow = Flow.new(OUTPUT, type_flow, label, date)

    begin
      client = Google_analytics.new(profil_id_ga)
      begin
        res = client.execute(dimensions, metrics, startDate, endDate, options)
        to_file(res, output_flow)
      rescue Exception => e
        if $envir == "development"
          # copie test file to output
          begin
            FileUtils.cp("#{TEST}#{type_flow}#{SEPARATOR6}#{label}.txt",
                         output_flow.absolute_path)
          rescue Exception => e
            Common.alert(e.message)
            raise Scraping_google_analyticsException
          end
        else
          Common.alert("Scraping to google analytics failed #{e.message}")
          raise Scraping_google_analyticsException
        end
      end
    rescue Exception => e
      if $envir == "development"
        # copie test file to output
        begin

          FileUtils.cp("#{TEST}#{type_flow}#{SEPARATOR6}#{label}.txt",
                       output_flow.absolute_path)

        rescue Exception => e
          Common.alert(e.message)
          raise Scraping_google_analyticsException
        end
      else
        Common.alert("connection to google analytics failed #{e.message}")
        raise Scraping_google_analyticsException
      end
    end
    Common.information("flow <#{output_flow.basename}> is ready")
    output_flow
  end


# public
  module_function :Scraping_hourly_daily_distribution
  module_function :Scraping_behaviour
# private
  module_function :to_file
  module_function :scraping
end
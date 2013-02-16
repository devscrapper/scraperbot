#!/usr/bin/env ruby -w
# encoding: UTF-8

require 'ruby-progressbar'
require 'fileutils'
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
  MAX_RESULTS = 10000
  LOG_FILE = File.dirname(__FILE__) + "/../log/" + File.basename(__FILE__, ".rb") + ".log"
  PARAMETERS = File.dirname(__FILE__) + "/../parameter/" + File.basename(__FILE__, ".rb") + ".yml"

  #--------------------------------------------------------------------------------------------------------------
  # scraping_device_platform_plugin
  #--------------------------------------------------------------------------------------------------------------

  #browser:  "Chrome", "Firefox", "Internet Explorer", "Safari"

  #operatingSystem:  "Windows", "Linux", "Macintosh"
  # --------------------------------------------------------------------------------------------------------------

  def Scraping_device_platform_plugin(label, date, profil_id_ga)
    Common.information("Scraping device platform plugin for #{label} for #{date} is starting")
    output_flow = nil
    begin
      params = YAML::load(File.open(PARAMETERS), "r:UTF-8")
      raise Scraping_google_analyticsException, "filter browser is not define" if params["browser"].nil?
      raise Scraping_google_analyticsException, "filter operatingSystem is not define" if params["operatingSystem"].nil?
      options={}
      # ATTENTION : le filtrage ne peut contenir que des rubriques présentes OBLIGATOIREMENT dans la requete dans metrics or dimension
      # si un filtre n'est pas présent la requete echoué.
      options["filters"] = {
          "flashVersion" => "!(not set)",
          "javaEnabled" => "!(not set)",
          "browserVersion" => "!(not set)",
          "operatingSystemVersion" => "!(not set)",
          "browser" => params["browser"],
          "operatingSystem" => params["operatingSystem"],
          "isMobile" => "No"
      }
      options["sort"] = "-visits"
      options["max-results"] = MAX_RESULTS

      output_flow = scraping("scraping-device-platform-plugin",
                             label,
                             date,
                             profil_id_ga,
                             "browser,browserVersion,operatingSystem,operatingSystemVersion,flashVersion,javaEnabled,isMobile",
                             "visits",
                             DateTime.now.prev_month(6).strftime("%Y-%m-%d"), # fenetre glissante de selection de 6 mois
                             DateTime.now.prev_day(1).strftime("%Y-%m-%d"),
                             options,
                             0) # percent de resultat conservé
    rescue Exception => e
      Common.alert("Scraping device platform plugin for #{label} failed #{e.message}")
    end

    # pousser le flow vers input_flow_server sur engine_bot
    begin
      output_flow.push($authentification_server_port,
                       $input_flows_server_ip,
                       $input_flows_server_port,
                       $ftp_server_port)
    rescue Exception => e
      Common.alert("Output_flow device platform plugin push to input flow server for #{label} failed #{e.message}")
    end
    begin
      options = {"path" => "/websites/#{label}/device_platforme_querying_date",
                 "scheme" => "http"}
      Information.new({"date" => Date.today}).send_to($statupweb_server_ip, $statupweb_server_port, options)
      Common.information("Updating device platform querying date for Website <#{label}>")
    rescue Exception => e
      Common.alert("Updating device platform querying for Website <#{label}> failed : #{e.message}")
    end
    Common.information("Scraping device platform plugin for #{label} is over")
  end


  #--------------------------------------------------------------------------------------------------------------
  # scraping_device_platform_resolution
  #--------------------------------------------------------------------------------------------------------------

  # --------------------------------------------------------------------------------------------------------------

  def Scraping_device_platform_resolution(label, date, profil_id_ga)

    Common.information("Scraping device platform resolution for #{label} for #{date} is starting")
    output_flow = nil
    begin
      params = YAML::load(File.open(PARAMETERS), "r:UTF-8")
      raise Scraping_google_analyticsException, "filter browser is not define" if params["browser"].nil?
      raise Scraping_google_analyticsException, "filter operatingSystem is not define" if params["operatingSystem"].nil?
      options={}
      # ATTENTION : le filtrage ne peut contenir que des rubriques présentes OBLIGATOIREMENT dans la requete dans metrics or dimension
      # si un filtre n'est pas présent la requete echoué.
      options["filters"] = {
          "flashVersion" => "!(not set)",
          "javaEnabled" => "!(not set)",
          "browserVersion" => "!(not set)",
          "operatingSystemVersion" => "!(not set)",
          "browser" => params["browser"],
          "operatingSystem" => params["operatingSystem"],
          "isMobile" => "No"
      }
      options["sort"] = "-visits"
      options["max-results"] = MAX_RESULTS


      output_flow = scraping("scraping-device-platform-resolution",
                             label,
                             date,
                             profil_id_ga,
                             "browser,browserVersion,operatingSystem,operatingSystemVersion,screenColors,screenResolution,isMobile",
                             "visits",
                             DateTime.now.prev_month(6).strftime("%Y-%m-%d"), # fenetre glissante de selection de 6 mois
                             DateTime.now.prev_day(1).strftime("%Y-%m-%d"),
                             options,
                             1) # percent de resultat conservé)
    rescue Exception => e
      Common.alert("Scraping device platform resolution for #{label} failed #{e.message}")
    end

    # pousser le flow vers input_flow_server sur engine_bot
    begin
      output_flow.push($authentification_server_port,
                       $input_flows_server_ip,
                       $input_flows_server_port,
                       $ftp_server_port)
    rescue Exception => e
      Common.alert("Output_flow device platform resolution push to input flow server for #{label} failed #{e.message}")
    end
    # maj date de scraping sur webstatup
    begin
      options = {"path" => "/websites/#{label}/device_platforme_querying_date",
                 "scheme" => "http"}
      Information.new({"date" => Date.today}).send_to($statupweb_server_ip, $statupweb_server_port, options)
      Common.information("Updating device platform querying date for Website <#{label}>")
    rescue Exception => e
      Common.alert("Updating device platform querying for Website <#{label}> failed : #{e.message}")
    end
    Common.information("Scraping device platform resolution for #{label} is over")
  end

  #--------------------------------------------------------------------------------------------------------------
  # scraping_traffic_source_landing_page
  #--------------------------------------------------------------------------------------------------------------

  # --------------------------------------------------------------------------------------------------------------

  def Scraping_traffic_source_landing_page(label, date, profil_id_ga)
    Common.information("Scraping traffic source for #{label} for #{date} is starting")

    output_flow = nil
    begin
      options={}
      options["sort"] = "-entrances"
      options["max-results"] = MAX_RESULTS

      output_flow = scraping("scraping-traffic-source-landing-page",
                             label,
                             date,
                             profil_id_ga,
                             "hostname,landingPagePath,referralPath,source,medium,keyword",
                             "entrances",
                             DateTime.now.prev_month(6).strftime("%Y-%m-%d"), # fenetre glissante de selection de 6 mois
                             DateTime.now.prev_day(1).strftime("%Y-%m-%d"),
                             options,
                             1) # percent de resultat conservé
    rescue Exception => e
      Common.alert("Scraping traffic source for #{label} failed #{e.message}")
    end

    # pousser le flow vers input_flow_server sur engine_bot
    begin
      output_flow.push($authentification_server_port,
                       $input_flows_server_ip,
                       $input_flows_server_port,
                       $ftp_server_port)
    rescue Exception => e
      Common.alert("Output_flow traffic source push to input flow server for #{label} failed #{e.message}")
    end
    # maj date de scraping sur webstatup
    begin
      options = {"path" => "/websites/#{label}/traffic_source_querying_date",
                 "scheme" => "http"}
      Information.new({"date" => Date.today}).send_to($statupweb_server_ip, $statupweb_server_port, options)
      Common.information("Updating traffic source landing page querying date for Website <#{label}>")
    rescue Exception => e
      Common.alert("Updating traffic source landing page querying for Website <#{label}> failed : #{e.message}")
    end
    Common.information("Scraping traffic source for #{label} is over")
  end


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
    begin
      output_flow.push($authentification_server_port,
                       $input_flows_server_ip,
                       $input_flows_server_port,
                       $ftp_server_port)
    rescue Exception => e
      Common.alert("Output_flow hourly daily distribution  push to input flow server for #{label} failed #{e.message}")
    end

    # maj date de scraping sur webstatup
    begin
      options = {"path" => "/websites/#{label}/hourly_daily_distribution_querying_date",
                 "scheme" => "http"}
      Information.new({"date" => Date.today}).send_to($statupweb_server_ip, $statupweb_server_port, options)
      Common.information("Updating hourly daily distribution querying date for Website <#{label}>")
    rescue Exception => e
      Common.alert("Updating hourly daily distribution querying for Website <#{label}> failed : #{e.message}")
    end
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
    begin
      output_flow.push($authentification_server_port,
                       $input_flows_server_ip,
                       $input_flows_server_port,
                       $ftp_server_port)
    rescue Exception => e
      Common.alert("Output_flow behaviour push to input flow server for #{label} failed #{e.message}")
    end

    begin
      options = {"path" => "/websites/#{label}/behaviour_querying_date",
                 "scheme" => "http"}
      Information.new({"date" => Date.today}).send_to($statupweb_server_ip, $statupweb_server_port, options)
      Common.information("Updating behaviour querying date for Website <#{label}>")
    rescue Exception => e
      Common.alert("Updating behaviour querying for Website <#{label}> failed : #{e.message}")
    end
    Common.information("Scraping behaviour for #{label} is over")
  end


#--------------------------------------------------------------------------------------------------------------
# private
#--------------------------------------------------------------------------------------------------------------
  def to_file(datas, type_flow, label, date)

    output_flow = Flow.new(OUTPUT, type_flow, label, date, 1)

    datas.each { |data|

      line = ""
      data.each { |key, value| line += "#{value}#{SEPARATOR2}" }

      output_flow.write("#{line}#{EOFLINE2}")

      if output_flow.size > Flow::MAX_SIZE

        # new flow
        output_flow = output_flow.new_volume()

      end
    }

    output_flow
  end


  def scraping(type_flow, label, date, profil_id_ga, dimensions, metrics, startDate, endDate, options, percent=0)

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


    begin
      client = Google_analytics.new(profil_id_ga)
      begin
        res = client.execute(dimensions, metrics, startDate, endDate, options)
        p "size(res) #{res.size}"
        res_filtered = filtering_with_filters(res, options["filters"])
        p "size(res filtered) #{res_filtered.size}"
        res_filtered = filtering_with_percent(res_filtered, metrics, percent)
        p "size(res filtered) #{res_filtered.size}"
        output_flow = to_file(res_filtered, type_flow, label, date)
        output_flow.volumes.each { |flow| Common.information("flow <#{flow.basename}> is ready") }
        output_flow
      rescue Exception => e
        if $envir == "development"
          # copie test file to output
          begin
            output_flow = Flow.new(OUTPUT, type_flow, label, date, 1)
            FileUtils.cp("#{TEST}#{type_flow}#{SEPARATOR6}#{label}.txt",
                         output_flow.absolute_path)
            output_flow
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
          output_flow = Flow.new(OUTPUT, type_flow, label, date, 1)
          FileUtils.cp("#{TEST}#{type_flow}#{SEPARATOR6}#{label}.txt",
                       output_flow.absolute_path)
          output_flow
        rescue Exception => e
          Common.alert(e.message)
          raise Scraping_google_analyticsException
        end
      else
        Common.alert("connection to google analytics failed #{e.message}")
        raise Scraping_google_analyticsException
      end
    end

  end

  def ou(filter, value_row)
    ok = false
    if filter.is_a?(Array)
      filter.each { |value|
        if value[0] != "!"
          ok = ok || value == value_row
        else
          value_complement = value[1..value.size - 1]
          ok = ok || value_complement != value_row
        end
      }
    else
      if filter[0] != "!"
        ok = ok || filter == value_row
      else
        value_complement = filter[1..filter.size - 1]
        ok = ok || value_complement != value_row
      end
    end
    ok
  end

  def et(filters, value_row)
    ok = true

    filters.each { |key, value|
      ok = ok && ou(value, value_row[key])
    }
    ok
  end


  def filtering_with_filters(data, filters)
    return data if filters.nil?
    data.delete_if { |row| !et(filters, row) }
  end

  def filtering_with_percent(data, metric, percent=0)
    # percent : est le pourcentage minimum que le metrics doit respecté pour conserver la dimension
    # si percent == 0 on garde tout
    # si percent == 1, le metric doit être >= 1% du total des metrics pour tous les resultats
    # le metric ne doit contenir qu'un attribut, si cela n'est pas le cas on garde tout
    return data if percent == 0 or
        metric.count(",") > 0 #il y a plus d'un metric et c'est pas bon
    total_metric =0
    data.each { |row| total_metric += row[metric].to_i }
    data.delete_if { |row| row[metric].to_i < (percent * total_metric / 100).to_i }
  end


# public
  module_function :Scraping_hourly_daily_distribution
  module_function :Scraping_behaviour
  module_function :Scraping_device_platform_plugin
  module_function :Scraping_device_platform_resolution
  module_function :Scraping_traffic_source_landing_page
# private
  module_function :to_file
  module_function :scraping
  module_function :filtering_with_filters
  module_function :filtering_with_percent
  module_function :et
  module_function :ou
end
#!/usr/bin/env ruby -w
# encoding: UTF-8

require 'ruby-progressbar'
require 'fileutils'

require_relative '../../lib/logging'
require_relative '../../lib/google_analytics'
require_relative '../flow'
require_relative '../authentification'

#------------------------------------------------------------------------------------------
# Pre requis gem
#------------------------------------------------------------------------------------------


module Scraping
  class Googleanalytics

    class GoogleanalyticsException < StandardError;
    end

#------------------------------------------------------------------------------------------
# Globals variables
#------------------------------------------------------------------------------------------

    TEST = File.dirname(__FILE__) + "/../../test/"
    OUTPUT = File.dirname(__FILE__) + "/../../output/"

    SEPARATOR="%SEP%"
    EOFLINE="%EOFL%"
    SEPARATOR2=";"
    SEPARATOR3="!"
    SEPARATOR4="|"
    SEPARATOR5=","
    SEPARATOR6="_"
    EOFLINE2 ="\n"
    MAX_RESULTS = 10000

    PARAMETERS = File.dirname(__FILE__) + "/../../parameter/" + File.basename(__FILE__, ".rb") + ".yml"
    attr :browsers, :operatingSystems, :logger

    def initialize()
      @logger = Logging::Log.new(self, :staging => $staging, :debugging => $debugging)
      begin
        params = YAML::load(File.open(PARAMETERS), "r:UTF-8")
        @browsers = params[$staging]["browsers"] unless params[$staging]["browsers"].nil?
        raise GoogleanalyticsException, "filter browser is not define" if params[$staging]["browsers"].nil?
        @operatingSystems = params[$staging]["operatingSystems"] unless params[$staging]["operatingSystems"].nil?
        raise GoogleanalyticsException, "filter operatingSystem is not define" if params[$staging]["operatingSystems"].nil?
      rescue Exception => e
        @logger.an_event.error "cannot load parameters file <#{PARAMETERS}>"
        @logger.an_event.debug e
      end
    end

#--------------------------------------------------------------------------------------------------------------
# scraping_device_platform_plugin
#--------------------------------------------------------------------------------------------------------------

#browser:  "Chrome", "Firefox", "Internet Explorer", "Safari"

#operatingSystem:  "Windows", "Linux", "Macintosh"
# --------------------------------------------------------------------------------------------------------------

    def device_platform_plugin(label, date, profil_id_ga, website_id)
      @logger.an_event.info "scraping device platform plugin for #{label} for #{date} is starting"
      output_flow = nil
      begin
        # ATTENTION : le filtrage ne peut contenir que des rubriques présentes OBLIGATOIREMENT dans la requete dans metrics or dimension
        # si un filtre n'est pas présent la requete echoué.
        options={}
        options["filters"] = {
            "flashVersion" => "!(not set)",
            "javaEnabled" => "!(not set)",
            "browserVersion" => "!(not set)",
            "operatingSystemVersion" => "!(not set)",
            "browser" => @browsers,
            "operatingSystem" => @operatingSystems,
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
        @logger.an_event.error "cannot scrape <device platform plugin> for #{label}"
        @logger.an_event.debug e
      end

      # pousser le flow vers input_flow_server sur
      begin
        output_flow.push($authentification_server_port,
                         $input_flows_server_ip,
                         $input_flows_server_port,
                         $ftp_server_port)
        @logger.an_event.info "push flow <#{output_flow.basename}> to input flow server for #{label}"
      rescue Exception => e
        @logger.an_event.error "cannot push flow #{output_flow.basename} to input flow server #{$input_flows_server_ip}:#{$input_flows_server_port} for #{label} failed"
        @logger.an_event.debug e
      end
      begin
        options = {"path" => "/websites/#{website_id}/device_platforme_querying_date",
                   "scheme" => "http"}
        Information.new({"date" => Date.today}).send_to($statupweb_server_ip, $statupweb_server_port, options)
        @logger.an_event.info "update querying date <device platform pluging> for website <#{label}>"
      rescue Exception => e
        @logger.an_event.error "cannot update querying date <device platform plugin> to #{$statupweb_server_ip}:#{$statupweb_server_port} for Website <#{label}>"
        @logger.an_event.debug e
      end
      @logger.an_event.info "scraping device platform plugin for #{label} is over"
    end


    #--------------------------------------------------------------------------------------------------------------
    # scraping_device_platform_resolution
    #--------------------------------------------------------------------------------------------------------------

    # --------------------------------------------------------------------------------------------------------------

    def device_platform_resolution(label, date, profil_id_ga, website_id)

      @logger.an_event.info "Scraping device platform resolution for #{label} for #{date} is starting"
      output_flow = nil
      begin
        options={}
        # ATTENTION : le filtrage ne peut contenir que des rubriques présentes OBLIGATOIREMENT dans la requete dans metrics or dimension
        # si un filtre n'est pas présent la requete echoué.
        options["filters"] = {
            "flashVersion" => "!(not set)",
            "javaEnabled" => "!(not set)",
            "browserVersion" => "!(not set)",
            "operatingSystemVersion" => "!(not set)",
            "browser" => @browsers,
            "operatingSystem" => @operatingSystems,
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
        @logger.an_event.error "Scraping device platform resolution for #{label} failed"
        @logger.an_event.debug e
      end

      # pousser le flow vers input_flow_server sur engine_bot
      begin
        output_flow.push($authentification_server_port,
                         $input_flows_server_ip,
                         $input_flows_server_port,
                         $ftp_server_port)
      rescue Exception => e
        @logger.an_event.error "Output_flow device platform resolution push to input flow server for #{label} failed"
        @logger.an_event.debug e
      end
      # maj date de scraping sur webstatup
      begin
        options = {"path" => "/websites/#{website_id}/device_platforme_querying_date",
                   "scheme" => "http"}
        Information.new({"date" => Date.today}).send_to($statupweb_server_ip, $statupweb_server_port, options)
        @logger.an_event.info "Updating device platform querying date for Website <#{label}>"
      rescue Exception => e
        @logger.an_event.error "Updating device platform querying for Website <#{label}> failed"
        @logger.an_event.debug e
      end
      @logger.an_event.info "Scraping device platform resolution for #{label} is over"
    end

    #--------------------------------------------------------------------------------------------------------------
    # scraping_traffic_source_landing_page
    #--------------------------------------------------------------------------------------------------------------

    # --------------------------------------------------------------------------------------------------------------

    def traffic_source_landing_page(label, date, profil_id_ga, website_id)
      @logger.an_event.info "Scraping traffic source for #{label} for #{date} is starting"

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
                               0) # percent de resultat conservé     #TODO etudier le pourcentage de resultat attendu
      rescue Exception => e
        @logger.an_event.error "Scraping traffic source for #{label} failed"
        @logger.an_event.debug e
      end

      # pousser le flow vers input_flow_server sur engine_bot
      begin
        output_flow.push($authentification_server_port,
                         $input_flows_server_ip,
                         $input_flows_server_port,
                         $ftp_server_port)
      rescue Exception => e
        @logger.an_event.error "Output_flow traffic source push to input flow server for #{label} failed"
        @logger.an_event.debug e
      end
      # maj date de scraping sur webstatup
      begin
        options = {"path" => "/websites/#{website_id}/traffic_source_querying_date",
                   "scheme" => "http"}
        Information.new({"date" => Date.today}).send_to($statupweb_server_ip, $statupweb_server_port, options)
        @logger.an_event.info "Updating traffic source landing page querying date for Website <#{label}>"
      rescue Exception => e
        @logger.an_event.error "Updating traffic source landing page querying for Website <#{label}> failed"
        @logger.an_event.debug e
      end
      @logger.an_event.info "Scraping traffic source for #{label} is over"
    end


#--------------------------------------------------------------------------------------------------------------
# Scraping_hourly_daily_distribution
#--------------------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------------------


    def hourly_daily_distribution(label, date, profil_id_ga, website_id)
      @logger.an_event.info "Scraping hourly daily distribution for #{label} for #{date} is starting"
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
        @logger.an_event.error "Scraping hourly_daily_distribution for #{label} failed"
        @logger.an_event.debug e
      end
      # pousser le flow vers input_flow_server sur engine_bot
      begin
        output_flow.push($authentification_server_port,
                         $input_flows_server_ip,
                         $input_flows_server_port,
                         $ftp_server_port)
      rescue Exception => e
        @logger.an_event.error "Output_flow hourly daily distribution  push to input flow server for #{label} failed"
        @logger.an_event.debug e
      end

      # maj date de scraping sur webstatup
      begin
        options = {"path" => "/websites/#{website_id}/hourly_daily_distribution_querying_date",
                   "scheme" => "http"}
        Information.new({"date" => Date.today}).send_to($statupweb_server_ip, $statupweb_server_port, options)
        @logger.an_event.info "Updating hourly daily distribution querying date for Website <#{label}>"
      rescue Exception => e
        @logger.an_event.error "Updating hourly daily distribution querying for Website <#{label}> failed"
        @logger.an_event.debug e
      end
      @logger.an_event.info "Scraping hourly daily distribution for #{label} is over"
    end


#--------------------------------------------------------------------------------------------------------------
# Scraping_behaviour
#--------------------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------------------
    def behaviour(label, date, profil_id_ga, website_id)
      @logger.an_event.info "Scraping behaviour for #{label} for #{date} is starting"
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
        @logger.an_event.error "Scraping behaviour for #{label} failed"
        @logger.an_event.debug e
      end

      # pousser le flow vers input_flow_server sur engine_bot
      begin
        output_flow.push($authentification_server_port,
                         $input_flows_server_ip,
                         $input_flows_server_port,
                         $ftp_server_port)
        @logger.an_event.info "push behaviour of #{label}"
      rescue Exception => e
        @logger.an_event.error "push behaviour of #{label} failed"
        @logger.an_event.debug e
      end

      begin
        options = {"path" => "/websites/#{website_id}/behaviour_querying_date",
                   "scheme" => "http"}
        Information.new({"date" => Date.today}).send_to($statupweb_server_ip, $statupweb_server_port, options)
        @logger.an_event.info "Update behaviour querying date for #{label}"
      rescue Exception => e
        @logger.an_event.warn "Update behaviour querying date for Website <#{label}> failed"
        @logger.an_event.debug e
      end
      @logger.an_event.info "Scraping behaviour for #{label} is over"
    end


#--------------------------------------------------------------------------------------------------------------
# private
#--------------------------------------------------------------------------------------------------------------
    def execute(query, basename_flow, dimensions, metrics, start_date, end_date, result_percent, label, date, profil_id_ga, options, uri_update_querying_date)
      @logger.an_event.info "scraping #{query} for #{label} for #{date} is starting"
      output_flow = nil
      begin

        output_flow = scraping(basename_flow,
                               label,
                               date,
                               profil_id_ga,
                               dimensions,
                               metrics,
                               start_date,
                               end_date,
                               options,
                               result_percent) # percent de resultat conservé
      rescue Exception => e
        @logger.an_event.error "cannot scrape <#{query}> for #{label}"
        @logger.an_event.debug e
      end

      # pousser le flow vers input_flow_server sur
      begin
        output_flow.push($authentification_server_port,
                         $input_flows_server_ip,
                         $input_flows_server_port,
                         $ftp_server_port)
        @logger.an_event.info "push flow <#{output_flow.basename}> to input flow server for #{label}"
      rescue Exception => e
        @logger.an_event.error "cannot push flow #{output_flow.basename} to input flow server #{$input_flows_server_ip}:#{$input_flows_server_port} for #{label} failed"
        @logger.an_event.debug e
      end
      begin
        options = {"path" => uri_update_querying_date,
                   "scheme" => "http"}
        Information.new({"date" => Date.today}).send_to($statupweb_server_ip, $statupweb_server_port, options)
        @logger.an_event.info "update querying date <#{query}> for website <#{label}>"
      rescue Exception => e
        @logger.an_event.error "cannot update querying date <#{query}> to #{$statupweb_server_ip}:#{$statupweb_server_port} for Website <#{label}>"
        @logger.an_event.debug e
      end
      @logger.an_event.info "scraping #{query} for #{label} is over"
    end

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

      @logger.an_event.debug "scraping to google analytics : "
      @logger.an_event.debug "type file : #{type_flow} "
      @logger.an_event.debug "label : #{label} "
      @logger.an_event.debug "date : #{date}"
      @logger.an_event.debug "profil_id_ga : #{profil_id_ga}"
      @logger.an_event.debug "dimensions : #{dimensions}"
      @logger.an_event.debug "metrics : #{metrics}"
      @logger.an_event.debug "startDate : #{startDate}"
      @logger.an_event.debug "endDate : #{endDate}"
      @logger.an_event.debug "options : #{options}"


      begin
        client = Google_analytics.new(profil_id_ga)
        res = client.execute(dimensions, metrics, startDate, endDate, options); @logger.an_event.debug "size(res) #{res.size}"

        res_filtered = filtering_with_filters(res, options["filters"]); @logger.an_event.debug "size(res filtered) #{res_filtered.size}"

        res_filtered = filtering_with_percent(res_filtered, metrics, percent); @logger.an_event.debug "size(res filtered) #{res_filtered.size}"

        output_flow = to_file(res_filtered, type_flow, label, date)
        output_flow.volumes.each { |flow| @logger.an_event.debug "flow <#{flow.basename}> is ready" }
        output_flow

      rescue Exception => e
        if $staging == "development"
          # copie test file to output
          begin
            output_flow = Flow.new(OUTPUT, type_flow, label, date, 1)
            FileUtils.cp("#{TEST}#{type_flow}#{SEPARATOR6}#{label.gsub(/[_ ]/, "-")}.txt",
                         output_flow.absolute_path)
            @logger.an_event.warn "use test file <#{type_flow}#{SEPARATOR6}#{label.gsub(/[_ ]/, "-")}.txt> for #{label}"
            output_flow
          rescue Exception => e
            @logger.an_event.error "cannot copy test file <#{TEST}#{type_flow}#{SEPARATOR6}#{label.gsub(/[_ ]/, "-")}.txt> to <#{output_flow.absolute_path}>"
            @logger.an_event.debug e
            raise GoogleanalyticsException
          end
        else
          @logger.an_event.error "query to google analytics for #{label} failed"
          @logger.an_event.debug e
          raise GoogleanalyticsException
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
  end
end
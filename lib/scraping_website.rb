#!/usr/bin/env ruby -w
# encoding: UTF-8
require 'rubygems'
require "em-http-request"
require File.dirname(__FILE__) + '/../lib/common'
require File.dirname(__FILE__) + '/../lib/logging'
require File.dirname(__FILE__) + '/../model/communication.rb'
require File.dirname(__FILE__) + '/../model/page.rb'


#------------------------------------------------------------------------------------------
# Pre requis gem
#------------------------------------------------------------------------------------------

module Scraping_website
  class Scraping_websiteException < StandardError;
  end
  include Common
#------------------------------------------------------------------------------------------
# Globals variables
#------------------------------------------------------------------------------------------
  LOG_FILE = File.dirname(__FILE__) + "/../log/" + File.basename(__FILE__, ".rb") + ".log"
  OUTPUT = File.dirname(__FILE__) + "/../output/"
  EOFLINE2 ="\n"
  SEPARATOR="%SEP%"
# Input
  attr :host # le hostname du site
# Output
  attr :f, #fichier contenant les links
       :ferror # fichier contenant les links en erreur
# Private
  attr :start_time, # heure de d�part
       :nbpage, # nbr de page du site
       :idpage, # cl� d'identification d'une page
       :known_url, # contient les liens identifi�s
       :count_page, # nombre de page que lon veut recuperer   0 <=> toutes les pages
       :schemes, #les schemes que l'on veut
       :types, # types de destination du lien : local au site, ou les sous-domaine, ou internet
       :date, #date des fichiers
       :label,
       :host,
       :run_spawn,
       :start_spawn,
       :stop_spawn,
       :push_file_spawn
#--------------------------------------------------------------------------------------------------------------
# scraping_device_platform_plugin
#--------------------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------------------

  def Scraping_pages(label, date, url_root, count_page, schemes, types)
    Common.information("Scraping pages for #{label} for #{date} is starting")
    @host = url_root
    @label = label
    @date = date
    @count_page = count_page
    @schemes = schemes
    @types = types

    @start_spawn = EM.spawn {
      Scraping_website.start()
    }
    @stop_spawn = EM.spawn {
      Scraping_website.stop()
    }
    @run_spawn = EM.spawn { |urls|
      Scraping_website.run(urls)
    }
    @push_file_spawn = EM.spawn { |id_file, last_volume|
      Scraping_website.push_file(id_file, last_volume)
    }

    @known_url = Hash.new(0)
    # delete les fichiers existants : on ne conserve qu'un resultat de scrapping par website
    delete_all_output_files
    @start_spawn.notify
  end

  def delete_all_output_files()

    Common.information("deleting all files website-#{@label}* ")
    Dir.entries(OUTPUT).each { |file|
      File.delete(OUTPUT + file) if File.fnmatch("website-#{@label}*", file)
    }
  end

  def start()

    @nbpage = 0
    @idpage = 1
    urls = Array.new
    urls << [@host, 1] # [url , le nombre d'essai de recuperation de la page associe a l'url]
    @known_url[@host] = @idpage
    @start_time = Time.now

    #creation du fichier de reporting des erreurs d'acces au lien contenus par les pages
    @ferror = Flow.new(OUTPUT, "website", @label, @date, 1, ".error")

    # creation du premier volume de données
    @f = Flow.new(OUTPUT, "website", @label, @date, 1, ".txt")

    #scraping website
    Common.debug("scrapping website options : ")
    Common.debug("count_page : #{@count_page}")
    Common.debug("schemes : #{@schemes}")
    Common.debug("types : #{@types}")
    @run_spawn.notify urls
    Common.information ("scrapping of #{@label} is running ")
  end

  def run(urls)

    url = urls.shift
    count_try = url[1]
    url = url[0]
    http = EM::HttpRequest.new(url).get :redirects => 2
    http.callback {
      id = @known_url[url]
      scraped_page = Page.new(id, url, http.response)
      scraped_page.title()
      scraped_page.body(:text)
      if @count_page > @idpage or @count_page == 0
        count_link = @count_page - @idpage if @count_page > 0
        count_link = @count_page unless @count_page > 0
        scraped_page.extract_links(@host, count_link, @schemes, @types).each { |link|
          if @known_url[link] == 0
            urls << [link, 1]
            @idpage += 1
            @known_url[link] = @idpage
          end
        }
      end
      scraped_page.links.map! { |link| @known_url[link] } unless scraped_page.links.nil?
      output(scraped_page)

      @nbpage += 1
      display(urls)
      if urls.size > 0 and
          (@count_page > @nbpage or @count_page == 0)

        @run_spawn.notify urls
      else
        @stop_spawn.notify
      end

    }

    http.errback {
      @ferror.write("url = #{url} try = #{count_try} Error = #{http.state}\n")
      count_try += 1
      urls << [url, count_try] if count_try < 4 # 3 essai max pour une url
      if urls.size > 0 and
          (@count_page > @nbpage or @count_page == 0)

        @run_spawn.notify urls
      else
        @stop_spawn.notify
      end
    }
  end


  def stop()
    Common.information("Scraping pages for #{@label} is over")
    @f.close
    @ferror.close

    # informer Load_server qu'il peut telecharger le dernier volume
    @push_file_spawn.notify @f, true
    # EM.stop pour le bench
    #TODO mettre à jour la date de scraping du website
    # maj date de scraping sur webstatup
  end


  private

  def display(urls)
    delay_from_start = Time.now - @start_time
    mm, ss = delay_from_start.divmod(60) #=> [4515, 21]
    hh, mm = mm.divmod(60) #=> [75, 15]
    dd, hh = hh.divmod(24) #=> [3, 3]
    Common.information("#{@label} nb page = #{@nbpage}  from start = #{dd} days, #{hh} hours, #{mm} minutes and #{ss.round(0)} seconds  avancement = #{((@nbpage * 100)/(@nbpage + urls.size)).to_i}%  nb/s = #{(@nbpage/delay_from_start).round(2)}  raf #{urls.size} links")
  end


  private
  def output(page)
    uri = URI.parse(page.url)
    host_path = uri.host + uri.path
    @f.write(page.to_s + "#{EOFLINE2}")

    if  @f.size > Flow::MAX_SIZE
      # informer Load_server qu'il peut telecharger le fichier
      @push_file_spawn.notify @f, false
      @f = @f.new_volume()
    end
  end

  def push_file(id_file, last_volume = false)
    begin
      id_file.push($authentification_server_port,
                   $input_flows_server_ip,
                   $input_flows_server_port,
                   $ftp_server_port,
                   id_file.vol, # on pousse que ce volume
                   last_volume)
    rescue Exception => e
      Common.alert("push flow <#{id_file}> to inputflows_server (#{$input_flows_server_ip}:#{$input_flows_server_port}) failed")
    end
  end

# public
  module_function :Scraping_pages
  module_function :start
  module_function :run
  module_function :stop
  module_function :push_file
  module_function :output
  module_function :display
  module_function :delete_all_output_files
# private
end
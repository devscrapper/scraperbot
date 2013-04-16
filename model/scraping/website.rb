#!/usr/bin/env ruby -w
# encoding: UTF-8
require 'rubygems'
require "em-http-request"

require_relative '../../lib/logging'
require_relative '../communication.rb'
require_relative 'page'


#------------------------------------------------------------------------------------------
# Pre requis gem
#------------------------------------------------------------------------------------------

module Scraping
  class Website
    class Scraping_websiteException < StandardError;
    end

#------------------------------------------------------------------------------------------
# Globals variables
#------------------------------------------------------------------------------------------
    OUTPUT = File.dirname(__FILE__) + "/../../output/"
    EOFLINE ="\n"
    SEPARATOR="%SEP%"
# Input
    attr :host # le hostname du site
# Output
    attr :f, #fichier contenant les links
         :ferror # fichier contenant les links en erreur
    :fleaves #fichier contenant les id des links ne contenant pas de lien
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
         :push_file_spawn,
         :website_id
#--------------------------------------------------------------------------------------------------------------
# scraping_device_platform_plugin
#--------------------------------------------------------------------------------------------------------------

# --------------------------------------------------------------------------------------------------------------
    def initialize()
      @logger = Logging::Log.new(self, :staging => $staging, :debugging => $debugging)
    end

    def scraping_pages(label, date, url_root, count_page, schemes, types, website_id)


      @logger.an_event.info("Scraping pages for #{label} for #{date} is starting")
      @host = url_root
      @label = label
      @date = date
      @count_page = count_page
      @schemes = schemes
      @types = types
      @website_id = website_id
      $sem = Mutex.new
      w = self
      @start_spawn = EM.spawn {
        w.start()
      }
      @stop_spawn = EM.spawn {
        w.stop()
      }
      @run_spawn = EM.spawn { |urls|
        w.run(urls)
      }
      @push_file_spawn = EM.spawn { |id_file, last_volume|
        w.push_file(id_file, last_volume)
      }

      @known_url = Hash.new(0)
      # delete les fichiers existants : on ne conserve qu'un resultat de scrapping par website
      delete_all_output_files
      @start_spawn.notify
    end

    def delete_all_output_files()

      @logger.an_event.info("deleting all files website-#{@label}* ")
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

      #creation du fichier contenant les pages ou uri qui sont des feuilles du site
      @fleaves = Flow.new(OUTPUT, "website", @label, @date, 0, ".txt")

      #creation du fichier de reporting des erreurs d'acces au lien contenus par les pages
      @ferror = Flow.new(OUTPUT, "website", @label, @date, 1, ".error")

      # creation du premier volume de données
      @f = Flow.new(OUTPUT, "website", @label, @date, 1, ".txt")

      #scraping website
      @logger.an_event.debug("scrapping website options : ")
      @logger.an_event.debug("count_page : #{@count_page}")
      @logger.an_event.debug("schemes : #{@schemes}")
      @logger.an_event.debug("types : #{@types}")
      @run_spawn.notify urls
      @logger.an_event.info ("scrapping of #{@label} is running ")
    end

    def run(urls)
      #TODO tester la réentrance car uand il y a hellobay et epilation qui demarre en même temp c'est le deuxième qui sexecute 2 fois
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
          $sem.synchronize {
            scraped_page.extract_links(@host, count_link, @schemes, @types).each { |link|
              if @known_url[link] == 0
                urls << [link, 1]
                @idpage += 1
                @known_url[link] = @idpage
              end
            } }
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
      @logger.an_event.info("Scraping pages for #{@label} is over")
      @f.close
      @ferror.close
      @fleaves.close if @fleaves.exist?
      # si il n'existe pas de feuille le fichier n'est pas créé, il faut donc le créé vide (size=0) pour que le
      # traitement de building matrix & page puisse se réaliser
      @fleaves.empty unless @fleaves.exist?

      # informer input flow server qu'il peut telecharger le dernier volume
      @push_file_spawn.notify @fleaves, false
      # informer input flow server qu'il peut telecharger le dernier volume
      @push_file_spawn.notify @f, true
      # maj date de scraping sur webstatup
      begin
        options = {"path" => "/websites/#{@website_id}/scraping_date",
                   "scheme" => "http"}
        Information.new({"date" => Date.today}).send_to($statupweb_server_ip, $statupweb_server_port, options)
        @logger.an_event.info("Updating scraping date for Website <#{@label}>")
      rescue Exception => e
        @logger.an_event.debug e
        @logger.an_event.warn("cannot update scraping date for Website <#{@label}>")
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
        @logger.an_event.info("push flow <#{id_file.basename}> to input flows server (#{$input_flows_server_ip}:#{$input_flows_server_port})")
      rescue Exception => e
        @logger.an_event.debug e
        @logger.an_event.error("cannot push flow <#{id_file.basename}> to input flows server (#{$input_flows_server_ip}:#{$input_flows_server_port})")
      end
    end

    private

    def display(urls)
      delay_from_start = Time.now - @start_time
      mm, ss = delay_from_start.divmod(60) #=> [4515, 21]
      hh, mm = mm.divmod(60) #=> [75, 15]
      dd, hh = hh.divmod(24) #=> [3, 3]
      @logger.an_event.info("#{@label} nb page = #{@nbpage}  from start = #{dd} days, #{hh} hours, #{mm} minutes and #{ss.round(0)} seconds  avancement = #{((@nbpage * 100)/(@nbpage + urls.size)).to_i}%  nb/s = #{(@nbpage/delay_from_start).round(2)}  raf #{urls.size} links")
    end
    def output(page)
      # on conserve l'identification des feuilles car cela ne coute pas cher et donne des informations sur la topologie du site
      # mais ces feuilles ne sont pas utilisées dans le calcul de la matrix fait par engine bot car risque de perdre trop de page si la topologie
      # du site est un arbre sans cycle.
     @fleaves.write("#{page.id}#{EOFLINE}") if page.is_leaf?
      @f.write(page.to_s + "#{EOFLINE}")
      if  @f.size > Flow::MAX_SIZE
        # informer input flow server qu'il peut telecharger le fichier
        output_file = @f
        @f = output_file.new_volume()
        @push_file_spawn.notify output_file, false
      end
    end


  end
end
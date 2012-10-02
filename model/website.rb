require 'rubygems'
require 'eventmachine'
require 'json'
require 'json/ext'
require File.dirname(__FILE__) + '/page.rb'
require File.dirname(__FILE__) + '/scraping.rb'
require File.dirname(__FILE__) + '/../lib/logging'
require File.dirname(__FILE__) + '/../lib/exchange_file'
require File.dirname(__FILE__) + '/../lib/google_analytics'
require 'logger'

# ---------------------------------------------------------------------------------------------------------------------
# TODO :
# rediger les commentaires pour les input
# informer le modele repository qu'une nouvelle version d'un site est dispo en indiquant sa localisation
# ---------------------------------------------------------------------------------------------------------------------
class Website < Scraping
  include Exchange_file
  include Google_analytics

  # Input
  attr :host # le hostname du site
  # Output
  attr
  :ferror # fichier contenant les links en erreur
  # Private
  attr :start_time, # heure de d�part
       :nbpage, # nbr de page du site
       :idpage, # cl� d'identification d'une page
       :known_url, # contient les liens identifi�s
       :count_page, # nombre de page que lon veut recuperer  ; 0 <=> toutes les pages
       :schemes, #les schemes que l'on veut
       :type, # type de destination du lien : local au site, ou les sous-domaine, ou internet
       :run_spawn,
       :start_spawn,
       :stop_spawn,
       :push_file_spawn,
       :avg_time_on_page, # temps passé sur les pages
       :profil_id_ga


  def initialize(connection, label=nil, url = nil, profil_id_ga = nil)
    super(connection, label)
    @profil_id_ga = profil_id_ga
    @host = url
    @known_url = Hash.new(0)
  end


  def start()
    @nbpage = 0
    @idpage = 1
    #@volume = 1
    @today = Date.today
    urls = Array.new
    urls << [@host, 1] # [url , le nombre d'essai de recuperation de la page associe a l'url]
    @known_url[@host] = @idpage
    @start_time = Time.now

    # delete les fichiers existants : on ne conserve qu'un resultat de scrapping par website
    delete_all_output_files

    #creation du fichier de reporting des erreurs d'acces au lien contenus par les pages
    @ferror = File.open(OUTPUT + "#{self.class}-#{@label}-#{@today}.error", "w:utf-8")
    @ferror.sync = true

    # creation du premier volume de données et du fichier des erreurs
    new_volume_output_file

    #scraping avgtime par page
    avg_time_on_page

    #scraping website
    Logging.send(@log_file, Logger::DEBUG, "scrapping website options : ")
    Logging.send(@log_file, Logger::DEBUG, "count_page : #{@count_page}")
    Logging.send(@log_file, Logger::DEBUG, "schemes : #{@schemes}")
    Logging.send(@log_file, Logger::DEBUG, "type : #{@type}")
    @run_spawn.notify urls
    Logging.send(@log_file, Logger::INFO, "scrapping of #{@label} is running ")
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

        scraped_page.extract_links(@host, count_link, @schemes, @type).each { |link|
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
        @f.write(EOF_ROW)
        @run_spawn.notify urls
      else
        @stop_spawn.notify
      end

    }

    http.errback {
      @ferror.write("url = #{url} try = #{count_try} Error = #{http.state}\n")
      count_try += 1
      urls << [url, count_try] if count_try < 4 # 3 essai max pour une url
      @run_spawn.notify urls if urls.size > 0
    }
  end


  def stop()
    Logging.send(@log_file, Logger::INFO, "scrapping of #{@label} is stopping ")
    @f.close
    @ferror.close

    # informer Load_server qu'il peut telecharger le dernier volume
    @push_file_spawn.notify File.basename(@f)
    # EM.stop pour le bench
  end


  def scrape(options)
    # comportement par defaut du scraping :
    # pas de limite de nombre de page scrapper
    # seulement les page dont le scheme est http
    # les pages qui ont le meme domaine ou un sous domaine du host
    @count_page = options["count_page"].to_i unless options["count_page"].nil?
    @count_page = 0 if  options["count_page"].nil?
    @schemes = options["schemes"] unless options["schemes"].nil?
    @schemes = [:http] if  options["schemes"].nil?
    @type = options["type"] unless options["type"].nil?
    @type = [:local, :global] if  options["type"].nil?
    # comportement par defaut du scraping :
    # start_date = end_date sont le jour précédent
    @start_date = Date.parse(options["start_date"]) unless options["start_date"].nil?
    @start_date = Date.today.prev_day(1) if  options["start_date"].nil?
    @end_date = Date.parse(options["end_date"]) unless options["end_date"].nil?
    @end_date = Date.today.prev_day(1) if  options["end_date"].nil?

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
    @push_file_spawn = EM.spawn { |id_file|
      w.push_file(id_file)
    }
    @start_spawn.notify
  end

  private
  def avg_time_on_page()
    Logging.send(@log_file, Logger::DEBUG, "scrapping avg_time_on_page options : ")
    Logging.send(@log_file, Logger::DEBUG, "start_date : #{@start_date}")
    Logging.send(@log_file, Logger::DEBUG, "end date : #{@end_date}")

    @dimensions = "ga:hostname,ga:pagePath"
    @metrics = "ga:avgTimeOnPage"
    @filters = "ga:avgTimeOnPage!=0"
    @avg_time_on_page = Hash.new
    Logging.send(@log_file, Logger::INFO, "scrapping avg_time_on_page of #{@label} is running ")
    begin
      connect_to_ga(@profil_id_ga)

      execute().each { |page|
        #on ne conserve que les url classiques qui ne bugger pas
        begin
          url = "#{page["hostname"]}#{page["pagePath"]}"
          URI.parse(url)
          @avg_time_on_page[url] = page["avgTimeOnPage"]
        rescue Exception => e
        end
      }
      Logging.send(@log_file, Logger::DEBUG, "fetch avg_time_on_page for #{self.class.name}:#{@label} is ok")
    rescue Exception => e
      p "fetch avg_time_on_page for #{self.class.name}:#{@label}, failed"
      Logging.send(@log_file, Logger::ERROR, "fetch avg_time_on_page for #{self.class.name}:#{@label} failed : #{e.message}")
    end
    Logging.send(@log_file, Logger::INFO, "scrapping avg_time_on_page of #{@label} is terminated ")
    @avg_time_on_page
  end


  private
  def display(urls)
    delay_from_start = Time.now - @start_time
    mm, ss = delay_from_start.divmod(60) #=> [4515, 21]
    hh, mm = mm.divmod(60) #=> [75, 15]
    dd, hh = hh.divmod(24) #=> [3, 3]
    p "#{@label} nb page = #{@nbpage}  from start = #{dd} days, #{hh} hours, #{mm} minutes and #{ss.round(0)} seconds  avancement = #{((@nbpage * 100)/(@nbpage + urls.size)).to_i}%  nb/s = #{(@nbpage/delay_from_start).round(2)}  raf #{urls.size} links"
  end


  private
  def output(page)

      uri = URI.parse(page.url)
      host_path = uri.host + uri.path
      # le temps passé sur la page a pu etre recuperer de google analytics
      time_on_page = @avg_time_on_page[host_path] unless @avg_time_on_page[host_path].nil?
      # le temps passé sur la page n'a pas pu etre recuperer de google analytics
      time_on_page =  "" if @avg_time_on_page[host_path].nil?
      @f.write(page.to_s + ";#{time_on_page}")

      if  @f.size > @connection.output_file_size.to_i
        # informer Load_server qu'il peut telecharger le fichier
        @push_file_spawn.notify File.basename(@f)
        new_volume_output_file
      end
    end

  end

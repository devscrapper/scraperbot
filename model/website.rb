require 'rubygems'
require 'eventmachine'
require 'json'
require 'json/ext'
require File.dirname(__FILE__) + '/page.rb'
require File.dirname(__FILE__) + '/../lib/logging'
require File.dirname(__FILE__) + '/../model/flow'
require File.dirname(__FILE__) + '/../lib/common'
require 'logger'

#TODO valider website
class Website
  OUTPUT = File.dirname(__FILE__) + "/../output/"

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
       :type, # type de destination du lien : local au site, ou les sous-domaine, ou internet
       :date, #date des fichiers
       :run_spawn,
       :start_spawn,
       :stop_spawn,
       :push_file_spawn


  def initialize(label, date, url_root)
    @host = url_root
    @label = label
    @date = date
    @known_url = Hash.new(0)
    # delete les fichiers existants : on ne conserve qu'un resultat de scrapping par website
    delete_all_output_files
  end

  def scrape(count_page, schemes, types)
      @count_page = count_page
      @schemes = schemes
      @types = types
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

  def start()
    @nbpage = 0
    @idpage = 1
    urls = Array.new
    urls << [@host, 1] # [url , le nombre d'essai de recuperation de la page associe a l'url]
    @known_url[@host] = @idpage
    @start_time = Time.now

    #creation du fichier de reporting des erreurs d'acces au lien contenus par les pages
    @ferror = Flow.new(OUTPUT, self.class.downcase, @label, @date, ".error")

    # creation du premier volume de données
    @f = Flow.new(OUTPUT, self.class.downcase, @label, @date, ".txt", 1)

    #scraping website
    debug("scrapping website options : ")
    debug("count_page : #{@count_page}")
    debug("schemes : #{@schemes}")
    debug("types : #{@types}")
    @run_spawn.notify urls
    information ("scrapping of #{@label} is running ")
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
    information("scrapping of #{@label} is stopping ")
    @f.close
    @ferror.close

    # informer Load_server qu'il peut telecharger le dernier volume
    @push_file_spawn.notify @f, true
    # EM.stop pour le bench
  end




  private

  def display(urls)
    delay_from_start = Time.now - @start_time
    mm, ss = delay_from_start.divmod(60) #=> [4515, 21]
    hh, mm = mm.divmod(60) #=> [75, 15]
    dd, hh = hh.divmod(24) #=> [3, 3]
    information("#{@label} nb page = #{@nbpage}  from start = #{dd} days, #{hh} hours, #{mm} minutes and #{ss.round(0)} seconds  avancement = #{((@nbpage * 100)/(@nbpage + urls.size)).to_i}%  nb/s = #{(@nbpage/delay_from_start).round(2)}  raf #{urls.size} links")
  end


  private
  def output(page)
    uri = URI.parse(page.url)
    host_path = uri.host + uri.path
    @f.write(page.to_s + "#{EOF_ROW}")

    if  @f.size > Flow::MAX_SIZE
      # informer Load_server qu'il peut telecharger le fichier
      @push_file_spawn.notify @f
      @f.close
      @f.new_volume()
    end
  end

  def delete_all_output_files()
    information("deleting all files #{self.class.downcase}-#{@label}* ")
    Dir.entries(OUTPUT).each { |file|
      File.delete(OUTPUT + file) if File.fnmatch("#{self.class.downcase}-#{@label}*", file)
    }
  end

  def push_file(id_file, last_volume = false)
    id_file.push($authentification_server_port,
                 $input_flows_server_ip,
                 $input_flows_server_port,
                 $ftp_server_port,
                 id_file.vol, # on pousse que ce volume
                 last_volume)
  end


end

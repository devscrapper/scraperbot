require 'rubygems'
require 'eventmachine'
require 'json'
require 'json/ext'
require File.dirname(__FILE__) + '/page.rb'
require File.dirname(__FILE__) + '/../lib/logging'
require 'logger'

# ---------------------------------------------------------------------------------------------------------------------
# TODO :
# rediger les commentaires pour les input
# informer le modele repository qu'une nouvelle version d'un site est dispo en indiquant sa localisation
# ---------------------------------------------------------------------------------------------------------------------
class Website
  OUTPUT = File.dirname(__FILE__) + "/../output/"
  @@log_file = File.dirname(__FILE__) + "/../log/" + File.basename(__FILE__, ".rb") + ".log"
  EOF_PAGE = "|"
  # Input
  attr :host # le hostname du site
  # Output
  attr :f, #fichier contenant les donn�es
       :ferror # fichier contenant les links en erreur
  # Private
  attr :today, #date du jour du premier volume => eviter que les fichiers n'aient pas la meme date
       :nbpage, # nbr de page du site
       :idpage, # cl� d'identification d'une page
       :known_url, # contient les liens identifi�s
       :start, # heure de d�part
       :volume, #numero du fichier
       :count_page, # nombre de page que lon veut recuperer  ; 0 <=> toutes les pages
       :schemes, #les schemes que l'on veut
       :type, # type de destination du lien : local au site, ou les sous-domaine, ou internet
       :run_spawn,
       :start_spawn,
       :stop_spawn,
       :push_file_spawn,
       :connection #la connection creee par le serveur


  def initialize(connection, url = nil)
    # url = nil si et seulement si on renvoit tous les fichiers de l'OUTPUT préfixé par le nom de la classe
    @connection = connection
    @host = url
    @known_url = Hash.new(0)
  end


  def start()
    @nbpage = 0
    @idpage = 1
    @volume = 1
    @today = Date.today
    urls = Array.new
    urls << [@host, 1] # [url , le nombre d'essai de recuperation de la page associe a l'url]
    @known_url[@host] = @idpage
    @start = Time.now

    # delete les fichiers existants : on ne conserve qu'un resultat de scrapping par website
    Logging.send(@@log_file, Logger::INFO, "deleting all files #{self.class}-#{URI.parse(@host).host}* ")
    Dir.entries(OUTPUT).each { |file|
      File.delete(OUTPUT + file) if File.fnmatch("#{self.class}-#{URI.parse(@host).host}*", file)
    }

    # creation du premier volume de données et du fichier des erreurs
    @f = File.open(OUTPUT + "#{self.class}-#{URI.parse(@host).host}-#{@today}-#{@volume}.txt", "w:utf-8")
    @ferror = File.open(OUTPUT + "#{self.class}-#{URI.parse(@host).host}-#{@today}.error", "w:utf-8")
    @f.sync = @ferror.sync = true
    @run_spawn.notify urls
    Logging.send(@@log_file, Logger::INFO, "scrapping of #{@host} is running ")
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
        @f.write(EOF_PAGE)
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
    Logging.send(@@log_file, Logger::INFO, "scrapping of #{@host} is stopping ")
    @f.close
    @ferror.close

    # informer Load_server qu'il peut telecharger le dernier volume
    @push_file_spawn.notify File.basename(@f)
    # EM.stop pour le bench
  end

  def push_file(id_file)

    begin
      response = get_authentification
      data = {"who" => self.class.name, "cmd" => "file", "label" => "label", "date_scraping" => @today, "id_file" => id_file, "user" => response["user"], "pwd" => response["pwd"]}
      Logging.send(@@log_file, Logger::DEBUG, "push file #{data}")
      s = TCPSocket.new @connection.load_server_ip, @connection.load_server_port
      s.puts JSON.generate(data)
      port, ip = Socket.unpack_sockaddr_in(s.getsockname)
      Logging.send(@@log_file, Logger::INFO, "push file #{id_file} from #{ip}:#{port} to #{@connection.load_server_ip}:#{@connection.load_server_port}")

      s.close
    rescue Exception => e
      Logging.send(@@log_file, Logger::ERROR, "push file #{id_file} failed to #{@connection.load_server_ip}:#{@connection.load_server_port} : #{e.message} : #{e.backtrace}")
    end

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
    Logging.send(@@log_file, Logger::INFO, "scrapping options : ")
    Logging.send(@@log_file, Logger::INFO, "count_page : #{@count_page}")
    Logging.send(@@log_file, Logger::INFO, "schemes : #{@schemes}")
    Logging.send(@@log_file, Logger::INFO, "type : #{@type}")
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

  def send_all_files()
    w = self
    @push_file_spawn = EM.spawn { |id_file|
      w.push_file(id_file)
    }
    port, ip = Socket.unpack_sockaddr_in(@connection.get_peername)
    begin
      Logging.send(@@log_file, Logger::INFO, "send all files to #{ip}:#{port}")
      Dir.entries(OUTPUT).each { |file|
        Logging.send(@@log_file, Logger::INFO, "#{file}") if File.fnmatch("#{self.class.name}*.txt", file)
        @push_file_spawn.notify file if File.fnmatch("#{self.class.name}*.txt", file)
      }
    rescue Exception => e
      Logging.send(@@log_file, Logger::ERROR, "send all files #{e.message} to #{port}:#{ip}")
    end
  end

  private
  def get_authentification
    begin
      s = TCPSocket.new 'localhost', @connection.authentification_server_port
      s.puts JSON.generate({"who" => self.class.name, "cmd" => "get"})
      get_response = JSON.parse(s.gets)
      port, ip = Socket.unpack_sockaddr_in(s.getsockname)
      Logging.send(@@log_file, Logger::INFO, "ask new authentification from  #{ip}:#{port} to 'localhost':#{@connection.authentification_server_port}")
      Logging.send(@@log_file, Logger::DEBUG, "new authentification #{get_response} from  #{ip}:#{port} to 'localhost':#{@connection.authentification_server_port}")
      s.close
    rescue Exception => e
      Logging.send(@@log_file, Logger::ERROR, "ask new authentification from  localhost':#{@connection.authentification_server_port} failed")
    end
    get_response
  end


  private
  def display(urls)
    delay_from_start = Time.now - @start
    mm, ss = delay_from_start.divmod(60) #=> [4515, 21]
    hh, mm = mm.divmod(60) #=> [75, 15]
    dd, hh = hh.divmod(24) #=> [3, 3]
    p "#{@host} nb page = #{@nbpage}  from start = #{dd} days, #{hh} hours, #{mm} minutes and #{ss.round(0)} seconds  avancement = #{((@nbpage * 100)/(@nbpage + urls.size)).to_i}%  nb/s = #{(@nbpage/delay_from_start).round(2)}  raf #{urls.size} links"

  end

  private
  def output(page)
    @f.write(page.to_s)
    if  @f.size > @connection.output_file_size.to_i
      # informer Load_server qu'il peut telecharger le fichier
      @push_file_spawn.notify File.basename(@f)
      @f.close
      @volume += 1
      @f = File.open(OUTPUT + "#{self.class}-#{URI.parse(@host).host}-#{@today}-#{@volume}.txt", "w:utf-8")
      @f.sync = true
    end
  end

  private
  def deletes()
    files = Array.new
    Dir.new(OUTPUT).entries.each { |n| files.push(n) if File.file?(n) }
  end
end


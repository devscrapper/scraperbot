require 'rubygems'
require 'eventmachine'
require 'json'
require 'json/ext'
require File.dirname(__FILE__) + '/page.rb'

# ---------------------------------------------------------------------------------------------------------------------
# TODO :
# rediger les commentaires pour les input
# informer le modele repository qu'une nouvelle version d'un site est dispo en indiquant sa localisation
# ---------------------------------------------------------------------------------------------------------------------
class Website
  OUTPUT = File.dirname(__FILE__) + "/../output/"
  # Input
  attr :host # le hostname du site
             # Output
  attr :f, #fichier contenant les donn�es
       :ferror # fichier contenant les links en erreur
             # Private
  attr :nbpage, # nbr de page du site
       :idpage, # cl� d'identification d'une page
       :known_url, # contient les liens identifi�s
       :start, # heure de d�part
       :run_spawn,
       :start_spawn,
       :stop_spawn

  def initialize(url)
    @host = url
    @known_url = Hash.new(0)
  end

  def start(count_page)
    @nbpage = 0
    @idpage = 1
    urls = Array.new
    urls << [@host, 1]    # [url , le nombre d'essai de recuperation de la page associ� � l'url]
    @known_url[@host] = @idpage
    @start = Time.now
    @count_page = count_page.to_i
    @f = File.open(OUTPUT + "#{self.class}-#{URI.parse(@host).host}-#{Date.today}.json", "w:utf-8")
    @ferror = File.open(OUTPUT + "#{self.class}-#{URI.parse(@host).host}-#{Date.today}.error", "w:utf-8")
    @f.sync = @ferror.sync = true
    @f.write("[")
    @run_spawn.notify urls
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
        scraped_page.extract_links(@host, count_link).each { |link|
          if @known_url[link] == 0
            urls << [link, 1]
            @idpage += 1
            @known_url[link] = @idpage
          end
        }
      end
      scraped_page.links.map! { |link| @known_url[link] } unless scraped_page.links.nil?
      begin
        @f.write(JSON.generate scraped_page)
      rescue Exception => e
        @ferror.write(scraped_page.url)
        @ferror.write(:body_not_html)
      end
      @nbpage += 1

      if urls.size > 0 and
          (@count_page > @nbpage or @count_page == 0)
        @f.write(",")
        @run_spawn.notify urls
      else
        @stop_spawn.notify
      end
      delay_from_start = Time.now - @start
      mm, ss = delay_from_start.divmod(60)            #=> [4515, 21]
      hh, mm = mm.divmod(60)           #=> [75, 15]
      dd, hh = hh.divmod(24)           #=> [3, 3]
      p "nb page = #{@nbpage}  from start = #{dd} days, #{hh} hours, #{mm} minutes and #{ss} seconds  avancement = #{((@nbpage * 100)/(@nbpage + urls.size)).to_i}%  nb/s = #{(@nbpage/delay_from_start).round(2)}  raf #{urls.size} links"
    }

    http.errback {
      @ferror.write("url = #{url} try = #{count_try} Error = #{http.state}\n")
      count_try += 1
      urls << [url, count_try] if count_try < 4 # 3 essai max pour une url
      @run_spawn.notify urls if urls.size > 0
    }
  end


  def stop()
    @f.write("]")
    @f.close
    @ferror.close
    # informer application rails quelle peut uploader les fichiers
  end

  def scrape(count_page = 0)
    w = self
    @start_spawn = EM.spawn { |count_page|
      w.start(count_page)
    }
    @stop_spawn = EM.spawn {
      w.stop()
    }
    @run_spawn = EM.spawn { |urls|
      w.run(urls)
    }

    @start_spawn.notify count_page
  end

end

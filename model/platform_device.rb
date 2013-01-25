require 'rubygems'
require 'json'
require 'json/ext'
require File.dirname(__FILE__) + '/page.rb'
require File.dirname(__FILE__) + '/../lib/logging'
require 'logger'
require File.dirname(__FILE__) + '/../model/google_analytics'
#TODO remplacer le separateur - par _ pour la generation des noms de fichier
# ---------------------------------------------------------------------------------------------------------------------
# TODO :
# rediger les commentaires pour les input
# ---------------------------------------------------------------------------------------------------------------------
class Platform_device < Google_analytics
  OUTPUT = File.dirname(__FILE__) + "/../output/"

  EOF_PAGE = "%EOFL%"
  # Input
  attr :connection #la connection creee par le serveur


  def initialize(connection, profil_id_ga)
    @connection = connection
    super(profil_id_ga, File.basename(__FILE__, ".rb") + ".log") # Analytics profile ID.
  end


  def scrape(options)
    # comportement par defaut du scraping :
    # start_date = end_date - un mois   on scrappe le mois qui précède

    @start_date = Date.parse(options["start_date"]) unless options["start_date"].nil?
    @start_date = Date.today.prev_month(1) if  options["start_date"].nil?
    @end_date = Date.parse(options["end_date"]) unless options["end_date"].nil?
    @end_date = Date.today if  options["end_date"].nil?

    browsers_version.each{|browser_version|
    }

    @dimensions = "ga:browser,ga:browserVersion,ga:operatingSystem,ga:operatingSystemVersion"
    @metrics = "ga:visitors"
    results = execute()
    Logging.send( @log_file, Logger::INFO, "platform_device : #{results}")
  end

  def browsers_version()
    @dimensions = "ga:browser,ga:browserVersion"
    @metrics = "ga:visitors"
    execute()
  end

 def operating_version()
   @dimensions = "ga:operatingSystem,ga:operatingSystemVersion"
   @metrics = "ga:visitors"
   execute()
 end

end


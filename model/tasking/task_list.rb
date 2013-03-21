require_relative '../scraping/google_analytics'
require_relative '../scraping/website'

module Tasking
  class Tasklist
    class TasklistException < StandardError;
    end
    include Scraping

    attr :data, :logger

    def initialize(data)
      @data = data
      @logger = Logging::Log.new(self, :staging => $staging, :debugging => $debugging)
    end

    def Scraping_behaviour()
      label = @data["label"]
      date_building = @data["date_building"]
      profil_id_ga = @data["data"]["profil_id_ga"]
      website_id = @data["data"]["website_id"]

      execute { Googleanalytics.new.behaviour(label, date_building, profil_id_ga, website_id) }
    end

    def Scraping_hourly_daily_distribution
      label = @data["label"]
      date_building = @data["date_building"]
      profil_id_ga = @data["data"]["profil_id_ga"]
      website_id = @data["data"]["website_id"]
      execute { Googleanalytics.new.hourly_daily_distribution(label, date_building, profil_id_ga, website_id) }
    end

    def Scraping_traffic_source_landing_page
      label = @data["label"]
      date_building = @data["date_building"]
      profil_id_ga = @data["data"]["profil_id_ga"]
      website_id = @data["data"]["website_id"]
      execute {Googleanalytics.new.traffic_source_landing_page(label, date_building, profil_id_ga, website_id)}
    end

    def Scraping_device_platform_resolution
      label = @data["label"]
      date_building = @data["date_building"]
      profil_id_ga = @data["data"]["profil_id_ga"]
      website_id = @data["data"]["website_id"]
      execute {Googleanalytics.new.device_platform_resolution(label, date_building, profil_id_ga, website_id)}
    end

    def Scraping_device_platform_plugin
      label = @data["label"]
      date_building = @data["date_building"]
      profil_id_ga = @data["data"]["profil_id_ga"]
      website_id = @data["data"]["website_id"]
      execute {Googleanalytics.new.device_platform_plugin(label, date_building, profil_id_ga, website_id)}
    end

    def Scraping_website
      label = @data["label"]
      date_building = @data["date_building"]
      url_root = @data["data"]["url_root"]
      count_page = @data["data"]["count_page"]
      schemes = @data["data"]["schemes"].split
      types = @data["data"]["types"].split
      website_id = @data["data"]["website_id"]
      execute {Website.new.scraping_pages(label, date_building, url_root, count_page, schemes, types, website_id)}
    end

    private
    def execute (&block)
      begin
        yield
      rescue Exception => e
        @logger.an_event.debug e
        raise TasklistException, e
      end
    end
  end
end

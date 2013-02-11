require 'rubygems'
require 'eventmachine'
require 'ice_cube'
require 'json'
require File.dirname(__FILE__) + '/../lib/logging'
require File.dirname(__FILE__) + '/../lib/common'
require File.dirname(__FILE__) + '/../model/communication'

class Event
  EXECUTE_ALL = "execute_all"
  EXECUTE_ONE = "execute_one"
  SAVE = "save"
  DELETE = "delete"

  attr :key,
       :periodicity,
       :cmd,
       :business


  def initialize(key, cmd, periodicity=nil, business=nil)
    @key = key
    @cmd = cmd
    @periodicity = periodicity
    @business = business
  end

  def to_json(*a)
    {
        "key" => @key,
        "cmd" => @cmd,
        "periodicity" => @periodicity,
        "business" => @business
    }.to_json(*a)
  end

  def to_s(*a)
    {
        "key" => @key,
        "cmd" => @cmd,
    }.to_s(*a)
  end

  def execute(load_server_port, time = Time.now)
    begin
      data = {
          "cmd" => @cmd,
          "label" => @business["label"],
          "date_building" => @key["building_date"] || Date.today,
          "data" => @business}
      Information.new(data).send_to(load_server_port)
      Common.information("send cmd #{@cmd} for #{@key["label"]} for #{data["date_building"]} at #{time} to scraper_server success")
    rescue Exception => e
      Common.alert("send cmd #{@cmd} for #{@key["label"]} for #{data["date_building"]} at #{time} to scraper_server failed : #{e.message}", __LINE__)
    end
  end
end


class Policy
  HOURLY_DAILY_DISTRIBUTION_DAY = -1 * IceCube::ONE_DAY #on decale d'un  jour j-1
  HOURLY_DAILY_DISTRIBUTION_HOUR = 0 * IceCube::ONE_HOUR #heure de démarrage est minuit
  BEHAVIOUR_DAY = -1 * IceCube::ONE_DAY #on decale d'un  jour j-1
  BEHAVIOUR_HOUR = 1 * IceCube::ONE_HOUR #heure de démarrage est minuit
  attr :label,
       :profil_id_ga,
       :policy_id,
       :periodicity

  def initialize(data)
    @label = data["label"]
    @profil_id_ga = data["profil_id_ga"]
    @policy_id = data["policy_id"]
    @periodicity = data["periodicity"]
  end

  def to_event()

    key = {"policy_id" => @policy_id
    }

    #Si demande suppression de la policy alors absence de periodicity et de business
    if @periodicity.nil?
      [Event.new(key,
                 "Scraping_hourly_daily_distribution"),
       Event.new(key,
                 "Scraping_behaviour")]
    else
      periodicity_hourly_daily_distribution = IceCube::Schedule.from_yaml(@periodicity)
      periodicity_hourly_daily_distribution.start_time += HOURLY_DAILY_DISTRIBUTION_DAY + HOURLY_DAILY_DISTRIBUTION_HOUR
      periodicity_hourly_daily_distribution.end_time += HOURLY_DAILY_DISTRIBUTION_DAY
      periodicity_hourly_daily_distribution.remove_recurrence_rule IceCube::Rule.weekly.day(:sunday)
      periodicity_hourly_daily_distribution.add_recurrence_rule IceCube::Rule.weekly.until(periodicity_hourly_daily_distribution.end_time)

      periodicity_behaviour = IceCube::Schedule.from_yaml(@periodicity)
      periodicity_behaviour.start_time += BEHAVIOUR_DAY + BEHAVIOUR_HOUR
      periodicity_behaviour.end_time += BEHAVIOUR_DAY
      periodicity_behaviour.remove_recurrence_rule IceCube::Rule.weekly.day(:sunday)
      periodicity_behaviour.add_recurrence_rule IceCube::Rule.weekly.until(periodicity_behaviour.end_time)

      business = {
          "profil_id_ga" => @profil_id_ga,
          "label" => @label
      }
      [Event.new(key,
                 "Scraping_hourly_daily_distribution",
                 periodicity_hourly_daily_distribution.to_yaml,
                 business),
       Event.new(key,
                 "Scraping_behaviour",
                 periodicity_behaviour.to_yaml,
                 business)]
    end
  end
end


class Website
  DEVICE_PLATFORM_PLUGIN_DAY = -1 * IceCube::ONE_DAY #on decale d'un  jour j-1
  DEVICE_PLATFORM_PLUGIN_HOUR = 0 * IceCube::ONE_HOUR #heure de démarrage est minuit
  DEVICE_PLATFORM_RESOLUTION_DAY = -1 * IceCube::ONE_DAY #on decale d'un  jour j-1
  DEVICE_PLATFORM_RESOLUTION_HOUR = 1 * IceCube::ONE_HOUR #heure de démarrage est 1h du matin
  TRAFFIC_SOURCE_LANDING_PAGE_DAY = -1 * IceCube::ONE_DAY #on decale d'un  jour j-1
  TRAFFIC_SOURCE_LANDING_PAGE_HOUR = 2 * IceCube::ONE_HOUR #heure de démarrage est 2h du matin
  attr :label,
       :profil_id_ga,
       :website_id,
       :periodicity,
       :url_root,
       :count_page,
       :schemes,
       :types

  def initialize(data)
    @label = data["label"]
    @profil_id_ga = data["profil_id_ga"]
    @website_id = data["website_id"]
    @periodicity = data["periodicity"]
    @url_root = data["url_root"]
    @count_page = data["count_page"]
    @schemes = data["schemes"]
    @types = data["types"]
  end

  def to_event()

    key = {"website_id" => @website_id
    }

    #Si demande suppression de la website alors absence de periodicity et de business
    if @periodicity.nil?
      [Event.new(key,
                 "Scraping_device_platform_plugin"),
       Event.new(key,
                 "Scraping_device_platform_resolution"),
       Event.new(key,
                 "Scraping_traffic_source_landing_page"),
       Event.new(key,
                 "Scraping_website")
      ]
    else
      #TODO controler la periodicité
      date_website = IceCube::Schedule.from_yaml(@periodicity).start_time

      start_time = date_website + DEVICE_PLATFORM_PLUGIN_DAY + DEVICE_PLATFORM_PLUGIN_HOUR
      periodicity_device_platform_plugin = IceCube::Schedule.new(start_time)
      periodicity_device_platform_plugin.add_recurrence_rule IceCube::Rule.daily

      start_time = date_website + DEVICE_PLATFORM_RESOLUTION_DAY + DEVICE_PLATFORM_RESOLUTION_HOUR
      periodicity_device_platform_resolution = IceCube::Schedule.new(start_time)
      periodicity_device_platform_resolution.add_recurrence_rule IceCube::Rule.daily

      start_time = date_website + TRAFFIC_SOURCE_LANDING_PAGE_DAY + TRAFFIC_SOURCE_LANDING_PAGE_HOUR
      periodicity_traffic_source_landing_page = IceCube::Schedule.new(start_time)
      periodicity_traffic_source_landing_page.add_recurrence_rule IceCube::Rule.daily

      business = {
          "label" => @label,
          "profil_id_ga" => @profil_id_ga
      }
      [Event.new(key,
                 "Scraping_device_platform_plugin",
                 periodicity_device_platform_plugin.to_yaml,
                 business),
       Event.new(key,
                 "Scraping_device_platform_resolution",
                 periodicity_device_platform_resolution.to_yaml,
                 business),
       Event.new(key,
                 "Scraping_traffic_source_landing_page",
                 periodicity_traffic_source_landing_page.to_yaml,
                 business),
       Event.new(key,
                 "Scraping_website",
                 @periodicity,
                 {
                     "label" => @label,
                     "profil_id_ga" => @profil_id_ga,
                     "url_root" => @url_root,
                     "count_page" => @count_page,
                     "schemes" => @schemes,
                     "types" => @types
                 })
      ]
    end
  end
end
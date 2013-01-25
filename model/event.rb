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
          "label" => @key["label"],
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
  BUILDING_OBJECTIVES_DAY = -1 * IceCube::ONE_DAY #on decale d'un  jour j-1
  BUILDING_OBJECTIVES_HOUR = 2 * IceCube::ONE_HOUR #heure de démarrage est 2h du matin
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

    key = {"policy_id" => @policy_id,
           "label" => @label
    }
    business = {
        "profil_id_ga" => @profil_id_ga
    }
    p "business #{business}"
    #Si demande suppression de la policy alors absence de periodicity et de business
    if @periodicity.nil?
      scraping_hourly_daily_distribution = Event.new(key,
                                                     "Scraping_hourly_daily_distribution")
      scraping_behaviour = Event.new(key,
                                     "Scraping_behaviour")
      [scraping_hourly_daily_distribution, scraping_behaviour]
    else
      #TODO : creer un class Building_objective qui herite de event
      periodicity = IceCube::Schedule.from_yaml(@periodicity)
      periodicity.start_time += BUILDING_OBJECTIVES_DAY + BUILDING_OBJECTIVES_HOUR
      periodicity.end_time += BUILDING_OBJECTIVES_DAY
      periodicity.remove_recurrence_rule IceCube::Rule.weekly.day(:sunday)
      periodicity.add_recurrence_rule IceCube::Rule.weekly.until(periodicity.end_time)
      scraping_hourly_daily_distribution = Event.new(key,
                                                     "Scraping_hourly_daily_distribution",
                                                     periodicity.to_yaml,
                                                     business)
      scraping_behaviour = Event.new(key,
                                     "Scraping_behaviour",
                                     periodicity.to_yaml,
                                     business)
      [scraping_hourly_daily_distribution, scraping_behaviour]
    end


  end
end


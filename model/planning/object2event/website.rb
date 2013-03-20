module Planning


  class Website
    DEVICE_PLATFORM_PLUGIN_DAY = -1 * IceCube::ONE_DAY #on decale d'un  jour j-1
    DEVICE_PLATFORM_PLUGIN_HOUR = 0 * IceCube::ONE_HOUR #heure de démarrage est minuit
    DEVICE_PLATFORM_RESOLUTION_DAY = -1 * IceCube::ONE_DAY #on decale d'un  jour j-1
    DEVICE_PLATFORM_RESOLUTION_HOUR = 1 * IceCube::ONE_HOUR #heure de démarrage est 1h du matin
    TRAFFIC_SOURCE_LANDING_PAGE_DAY = -1 * IceCube::ONE_DAY #on decale d'un  jour j-1
    TRAFFIC_SOURCE_LANDING_PAGE_HOUR = 2 * IceCube::ONE_HOUR #heure de démarrage est 2h du matin
    SCRAPING_WEBSITE_DAY = 1 * IceCube::ONE_DAY # on decale d'un jour le premier scraping, j+1
    SCRAPING_WEBSITE_HOUR = 3 * IceCube::ONE_HOUR # ond decale de 3 heures le demarrage, apres toute les query vers GA
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

      key = {"website_id" => @website_id}

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
        case @periodicity
          when "daily"
            rule_every = IceCube::Rule.daily
          when "weekly"
            rule_every = IceCube::Rule.weekly
          when "yearly"
            rule_every = IceCube::Rule.yearly
          else
        end

        # iceCube a besoin d'un Time et pas d'un Date
        today = Time.local(Date.today.year, Date.today.month, Date.today.day)
        next_monday = Time.local(next_monday(Date.today).year,
                                 next_monday(Date.today).month,
                                 next_monday(Date.today).day)
        # pas de date de fin, car c'est la suppression du website qui supprime la recuperation des données et du scraping
        periodicity_scraping_website = IceCube::Schedule.new(today + SCRAPING_WEBSITE_DAY + SCRAPING_WEBSITE_HOUR)
        periodicity_scraping_website.add_recurrence_rule rule_every

        # on demarre la planification pour le prochain lundi qui suit l'enregistrement du website
        # pas de date de fin, car c'est la suppression du website qui supprime la recuperation des données et du scraping
        periodicity_device_platform_plugin = IceCube::Schedule.new(next_monday + DEVICE_PLATFORM_PLUGIN_DAY + DEVICE_PLATFORM_PLUGIN_HOUR)
        periodicity_device_platform_plugin.add_recurrence_rule IceCube::Rule.daily

        periodicity_device_platform_resolution = IceCube::Schedule.new(next_monday + DEVICE_PLATFORM_RESOLUTION_DAY + DEVICE_PLATFORM_RESOLUTION_HOUR)
        periodicity_device_platform_resolution.add_recurrence_rule IceCube::Rule.daily

        periodicity_traffic_source_landing_page = IceCube::Schedule.new(next_monday + TRAFFIC_SOURCE_LANDING_PAGE_DAY + TRAFFIC_SOURCE_LANDING_PAGE_HOUR)
        periodicity_traffic_source_landing_page.add_recurrence_rule IceCube::Rule.daily

        business = {
            "label" => @label,
            "profil_id_ga" => @profil_id_ga,
            "website_id" => @website_id
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
                   periodicity_scraping_website.to_yaml,
                   {
                       "label" => @label,
                       "profil_id_ga" => @profil_id_ga,
                       "url_root" => @url_root,
                       "count_page" => @count_page,
                       "schemes" => @schemes,
                       "types" => @types,
                       "website_id" => @website_id
                   })
        ]
      end
    end

    def next_monday(date)
      today = Date.parse(date) if date.is_a?(String)
      today = date if date.is_a?(Date)

      return today if today.monday?
      return today.next_day(1) if today.sunday?
      return today.next_day(2) if today.saturday?
      return today.next_day(3) if today.friday?
      return today.next_day(4) if today.thursday?
      return today.next_day(5) if today.wednesday?
      return today.next_day(6) if today.tuesday?
    end
  end
end
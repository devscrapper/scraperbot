require_relative '../../../model/planning/event'
module Planning



  class Policy
    HOURLY_DAILY_DISTRIBUTION_DAY = -1 * IceCube::ONE_DAY #on decale d'un  jour j-1
    HOURLY_DAILY_DISTRIBUTION_HOUR = 0 * IceCube::ONE_HOUR #heure de démarrage est minuit
    BEHAVIOUR_DAY = -1 * IceCube::ONE_DAY #on decale d'un  jour j-1
    BEHAVIOUR_HOUR = 1 * IceCube::ONE_HOUR #heure de démarrage est minuit
    attr :label,
         :profil_id_ga,
         :policy_id,
         :monday_start,
         :count_weeks,
         :website_id

    def initialize(data)
      @label = data["label"]
      @profil_id_ga = data["profil_id_ga"]
      @policy_id = data["policy_id"]
      @website_id = data["website_id"]
      @monday_start = Time.local(data["monday_start"].year, data["monday_start"].month, data["monday_start"].day) unless data["monday_start"].nil? # iceCube a besoin d'un Time et pas d'un Date
      @count_weeks = data["count_weeks"].to_i unless data["count_weeks"].nil?
    end

    def to_event()
      key = {"policy_id" => @policy_id}

      #Si demande suppression de la policy alors absence de periodicity et de business
      if @count_weeks.nil? and @monday_start.nil?
        [Event.new(key,
                   "Scraping_hourly_daily_distribution"),
         Event.new(key,
                   "Scraping_behaviour")]
      else
        periodicity_hourly_daily_distribution = IceCube::Schedule.new(@monday_start + HOURLY_DAILY_DISTRIBUTION_DAY + HOURLY_DAILY_DISTRIBUTION_HOUR,
                                                                      :end_time => @monday_start + @count_weeks * IceCube::ONE_WEEK)
        periodicity_hourly_daily_distribution.add_recurrence_rule IceCube::Rule.weekly.until(@monday_start + @count_weeks * IceCube::ONE_WEEK)

        periodicity_behaviour = IceCube::Schedule.new(@monday_start + BEHAVIOUR_DAY + BEHAVIOUR_HOUR,
                                                      :end_time => @monday_start + @count_weeks * IceCube::ONE_WEEK)
        periodicity_behaviour.add_recurrence_rule IceCube::Rule.weekly.until(@monday_start + @count_weeks * IceCube::ONE_WEEK)

        business = {
            "profil_id_ga" => @profil_id_ga,
            "label" => @label,
            "website_id" => @website_id
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

end
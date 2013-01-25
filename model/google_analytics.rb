require 'rubygems'
require 'google/api_client'
require File.dirname(__FILE__) + '/../lib/logging'
require File.dirname(__FILE__) + '/../lib/common'
require 'logger'
require 'date'

class Google_analytics
  class Google_analyticsError < StandardError
  end
  CREDENTIALS = File.dirname(__FILE__) + "/../credentials/"
  PARAMETERS =  File.dirname(__FILE__) + "/../parameter/" + File.basename(__FILE__, ".rb") + ".yml"
  MAX_RESULT = 10000
  MAX_RESULT_PER_QUERY = 1000
  SEPARATOR = ","
  attr :client,
       :analytics,
       :profil_id_ga

  def initialize(profil_id_ga)
    @profil_id_ga = profil_id_ga
    #TODO valider la varabilisation des paramètres sécurité de google_api
    params = YAML::load(File.open(PARAMETERS) , "r:UTF-8")
    service_account_email = params[$envir]["service_account_email"] #"33852996685@developer.gserviceaccount.com" # Email of service account
    private_key =  params[$envir]["private_key"] #"7b2746cb605ca688f68d25d860cb6878e93e25c9-privatekey.p12"

    p "service_account_email #{service_account_email}"
    p "private_key #{private_key}"

    begin
      @client = Google::APIClient.new()
      key = Google::APIClient::PKCS12.load_key(CREDENTIALS + private_key,
                                               'notasecret')

      asserter = Google::APIClient::JWTAsserter.new(service_account_email,
                                                    'https://www.googleapis.com/auth/analytics.readonly',
                                                    key)
      @client.authorization = asserter.authorize()
      @analytics = @client.discovered_api('analytics', 'v3')
      Common.information("connection to google analytics for #{@profil_id_ga} is ok ")
    rescue Exception => e
      Common.error("connection to google analytics for #{@profil_id_ga} failed : #{e.message} ")
      raise Google_analyticsError, e.message
    end
  end

  def execute(dimensions, metrics, start_date, end_date, options={})
    # dimensions : dimension without ga:
    # metrics : metrics without ga:
    # options : max_elements_request : le nombre total d'element attendus
    # Options : filters with ga:
    # options : sort without ga:

    start_index = 1
    max_elements_request = MAX_RESULT if options["max_elements_request"].nil?
    max_elements_request = max_elements_request unless options["max_elements_request"].nil?

    params = {'ids' => "ga:#{@profil_id_ga}",
              'start-index' => start_index,
              'dimensions' => dimensions.split(SEPARATOR).map! { |dimension| "ga:#{dimension}" }.join(SEPARATOR),
              'metrics' => metrics.split(SEPARATOR).map! { |metric| "ga:#{metric}" }.join(SEPARATOR),
              'start-date' => start_date,
              'end-date' => end_date,
              'max-results' => Common.min(MAX_RESULT_PER_QUERY, max_elements_request)
    }
    if !options["sort"].nil?
      params['sort'] = options["sort"].split(SEPARATOR).map { |predica|
        if predica[0] == "-"
          "-ga:#{predica[1..predica.size-1]}"
        else
          "ga:#{predica}"
        end
      }.join(SEPARATOR)
    end

    params['filters'] = options["filters"] unless options["filters"].nil?
    Common.information("params query google analytics #{params}")

    continue = true
    results = []
    while continue
      begin
        results_ga = client.execute!(:api_method => @analytics.data.ga.get, :parameters => params)
        results_ga.data.rows.each { |row|
          res_row = {}
          row.each_index { |i|
            res_row.merge!({"#{remove_ga(results_ga.data.column_headers[i].name)}" => row[i]})
          }
          results << res_row
        }
      rescue Exception => e
        continue = false
        Common.error("request to google failed : #{e.message}")
        raise Google_analyticsError, e.message
      end
      start_index += MAX_RESULT_PER_QUERY - 1
      continue = false if start_index >= results_ga.data.totalResults or start_index >= max_elements_request
    end
    results
  end

  private
  def remove_ga(name)
    name[3..name.size-1]
  end

end

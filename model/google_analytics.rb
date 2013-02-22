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
  PARAMETERS = File.dirname(__FILE__) + "/../parameter/" + File.basename(__FILE__, ".rb") + ".yml"
#  MAX_RESULT = 10000
  MAX_RESULT_PER_QUERY = 10000
  SEPARATOR = ","
  attr :client,
       :analytics,
       :profil_id_ga

  def initialize(profil_id_ga)
    @profil_id_ga = profil_id_ga
    begin
      params = YAML::load(File.open(PARAMETERS), "r:UTF-8")
    rescue Exception => e
      Common.error("load parameter file #{PARAMETERS} : #{e.message}")
    end
    raise Google_analyticsError, "$envir is not define" if params[$envir].nil?
    raise Google_analyticsError, "service_account_email is not define" if params[$envir]["service_account_email"].nil?
    raise Google_analyticsError, "private_key is not define" if params[$envir]["private_key"].nil?

    service_account_email = params[$envir]["service_account_email"] #"33852996685@developer.gserviceaccount.com" # Email of service account
    private_key = params[$envir]["private_key"] #"7b2746cb605ca688f68d25d860cb6878e93e25c9-privatekey.p12"
    ENV['SSL_CERT_FILE'] = CREDENTIALS + "cacert.pem"

    Common.debug("ENV['SSL_CERT_FILE'] : #{ENV['SSL_CERT_FILE']}")
    Common.debug("service_account_email : #{service_account_email}")
    Common.debug("private key file :#{CREDENTIALS + private_key}")
    begin
      options = {:application_name => "querying_ga", :application_version => "v1"}
      @client = Google::APIClient.new(options)
    rescue Exception => e
      Common.error("creation client google api for #{@profil_id_ga} failed")
      Common.debug("#{e.message}")
      raise Google_analyticsError
    end
    begin
      @analytics = @client.discovered_api('analytics', 'v3')
    rescue Exception => e
      Common.error("discovering api analytics for #{@profil_id_ga} failed")
      Common.debug("#{e.message}")
      raise Google_analyticsError
    end
    begin
    key = Google::APIClient::PKCS12.load_key(CREDENTIALS + private_key,
                                             'notasecret')
    asserter = Google::APIClient::JWTAsserter.new(service_account_email,
                                                  'https://www.googleapis.com/auth/analytics.readonly',
                                                  key)
    @client.authorization = asserter.authorize()

    Common.information("connection to google analytics for #{@profil_id_ga} is available")
  rescue Exception => e
    Common.error("authorization to use google analytics for #{@profil_id_ga} failed")
    Common.debug("#{e.message}")
    raise Google_analyticsError
  end
end

def execute(dimensions, metrics, start_date, end_date, options={})
  # dimensions : dimension without ga:
  # metrics : metrics without ga:
  # options : max_elements_request : le nombre total d'element attendus
  # Options : filters with ga:
  # options : sort without ga:

  start_index = 1

  max_elements_request = MAX_RESULT_PER_QUERY if options["max-results"].nil?
  max_elements_request = options["max-results"].to_i unless options["max-results"].nil?

  params = {'ids' => "ga:#{@profil_id_ga}",
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
  #
  #params['filters'] = options["filters"] unless options["filters"].nil?
  #
  # Le filtrage n'est pas fait par google mais à posteriori par l'appelant.
  # il y a un bug dans le gem Faraday qui met en forme la requete http
  # voir Issue 57: 	Google Analytics API: filter with AND is impossible pour le gem google-api-ruby-client
  #
  #
  Common.debug("params query google analytics #{params}")

  continue = true
  results = []
  while continue
    begin
      params['start-index'] = start_index
      results_ga = @client.execute!(:api_method => @analytics.data.ga.get, :parameters => params)
      results_ga.data.rows.each { |row|
        res_row = {}
        row.each_index { |i|
          res_row.merge!({"#{remove_ga(results_ga.data.column_headers[i].name)}" => row[i]})
        }
        results << res_row
      }
      Common.information("request to google analytics from index #{params['start-index']} to index #{MAX_RESULT_PER_QUERY + params['start-index'].to_i}")
    rescue Exception => e
      continue = false
      Common.error("request to google analitycs failed")
      Common.debug("#{e.message}")
      raise Google_analyticsError, e.message
    end
    Common.debug("size(max result ga) #{results_ga.data.totalResults}")
    Common.debug("count row #{results.size}")
    start_index += MAX_RESULT_PER_QUERY
    continue = false if results.size >= results_ga.data.totalResults
  end
  results
end

private
def remove_ga(name)
  name[3..name.size-1]
end

end

#!/usr/bin/env ruby -w
# encoding: UTF-8

require 'ruby-progressbar'
require 'fileutils'
require File.dirname(__FILE__) + '/../lib/common'
require File.dirname(__FILE__) + '/../lib/logging'
require File.dirname(__FILE__) + '/../model/flow'
require File.dirname(__FILE__) + '/../model/website'
require File.dirname(__FILE__) + '/../model/authentification'

#------------------------------------------------------------------------------------------
# Pre requis gem
#------------------------------------------------------------------------------------------


module Scraping_website
  class Scraping_websiteException < StandardError;
  end
  include Common
#------------------------------------------------------------------------------------------
# Globals variables
#------------------------------------------------------------------------------------------

  TEST = File.dirname(__FILE__) + "/../test/"
  OUTPUT = File.dirname(__FILE__) + "/../output/"
  LOG_FILE = File.dirname(__FILE__) + "/../log/" + File.basename(__FILE__, ".rb") + ".log"


  #--------------------------------------------------------------------------------------------------------------
  # scraping_device_platform_plugin
  #--------------------------------------------------------------------------------------------------------------

  # --------------------------------------------------------------------------------------------------------------

  def Scraping_pages(label, date, url_root, count_page, schemes, types)
    Common.information("Scraping pages for #{label} for #{date} is starting")

    website = Website.new(label, date, url_root)

    website.scrape(count_page, schemes, types)

    #TODO mettre à jour la date de scraping du website
    # maj date de scraping sur webstatup
    Common.information("Scraping pages for #{label} is over")
  end


# public
  module_function :Scraping_pages

# private
end
#!/usr/bin/env ruby -w
# encoding: UTF-8
require "logging"

module Logging
  #tableau d'organisation des logs
  #--------------------------------------------------------------
  #         | DEBUGGING                 |    NOT DEBUGGING
  #--------------------------------------------------------------
  #         | PROD/TEST   |  DEV        |   PROD/TEST   |   DEV
  #---------------------------------------------------------------
  #> :fatal | email       | no          |   email       | no
  #---------------------------------------------------------------
  #> :info  | syslog,     | stdout      |   syslog,     | stdout
  #         |             |             |   rollfile    | rollfile
  #---------------------------------------------------------------
  #> :debug | rollfile    | rollfile    |               |
  #--------------------------------------------------------------
  STAGING_DEV = "development"
  STAGING_TEST = "test"
  STAGING_PROD = "production"

  class Log
    DIR_LOG =  File.dirname(__FILE__) + "/../log"
    attr_reader :logger
     attr    :staging,
         :debugging,
         :id_file
    alias :a_log :logger

    def initialize(obj, opts = {})
      @staging = opts.getopt(:staging, STAGING_PROD)
      @debugging = opts.getopt(:debugging, false)
      if obj.class.name == "Object"
        @id_file = opts.getopt(:id_file)
        @logger = Logging.logger["root"]
      else
        @id_file = obj.class.name
        @logger = Logging.logger[obj]
        @logger.additive = true
      end


      #TODO terminer l'appender syslog
      #syslog = Logging::appenders.syslog(obj.class.name)

      #TODO definir le parametrage de l'appender mail
      email = Logging::appenders.email('email',
                                       :from => "server@example.com",
                                       :to => "developers@example.com",
                                       :subject => "Application Error []",
                                       :address => "smtp.google.com",
                                       :port => 443,
                                       :domain => "google.com",
                                       :user_name => "example",
                                       :password => "12345",
                                       :authentication => :plain,
                                       :enable_starttls_auto => true,
                                       :auto_flushing => 200, # send an email after 200 messages have been buffered
                                       :flush_period => 60, # send an email after one minute
                                       :level => :fatal # only process log events that are "error" or "fatal"
      )
      rollfile = Logging::Appenders.rolling_file(File.join(DIR_LOG, "#{@id_file}.log"), {:age => :daily, :keep => 7, :roll_by => :date}) if obj.class.name == "Object" and !@debugging
      stdout = Logging::Appenders.stdout(:level => :info)


      if @debugging
        @logger.level = :debug
        @logger.trace = true
        log_debug_file = Logging::Appenders.rolling_file(File.join(DIR_LOG, "#{@id_file}.deb"), {:age => :daily, :keep => 7, :roll_by => :date, :layout => Logging.layouts.pattern(:pattern => '[%d] %-5l %-16c %-32M %-5L %x{,} :  %m %F\n')})
        yml_debug_file = Logging::Appenders.rolling_file(File.join(DIR_LOG, "#{@id_file}.yml"), {:age => :daily, :keep => 7, :roll_by => :date, :layout => Logging.layouts.yaml})
        @logger.add_appenders([log_debug_file, yml_debug_file])

        case @staging
          when STAGING_PROD, STAGING_TEST
            @logger.add_appenders(email)
          #TODO ajouter l'appender syslog
          #@logger.add_appenders(syslog)
          when STAGING_DEV
            @logger.add_appenders(stdout)
          else
            raise ArgumentError, "staging unknown <#{@staging}>"
        end

      else
        @logger.level = :info
        case @staging
          when STAGING_PROD, STAGING_TEST
            @logger.add_appenders(email)
            # @logger.add_appenders(syslog)
            @logger.add_appenders(rollfile) unless rollfile.nil?
          when STAGING_DEV
            @logger.add_appenders(stdout)
            @logger.add_appenders(rollfile) unless rollfile.nil?
          else
            raise ArgumentError, "staging unknown <#{@staging}>"
        end
      end
      @logger.info "logging is available"
    end

    #def info msg
    #  @logger.info msg;
    #end
    #
    #def debug msg
    #  @logger.debug msg;
    #end
    #
    #def warn msg
    #  @logger.warn msg;
    #end
    #
    #def error msg
    #  @logger.error msg;
    #end
    #
    #def fatal msg
    #  @logger.fatal msg;
    #end
  end
end
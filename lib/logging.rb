#!/usr/bin/env ruby -w
# encoding: UTF-8
#------------------------------------------------------------------------------------------
# Pre requis gem
#------------------------------------------------------------------------------------------

module Logging
#------------------------------------------------------------------------------------------
# get :
#------------------------------------------------------------------------------------------

#Logging.send(Logger::DEBUG, "debug",$0 )
#Logging.send(Logger::INFO, "info", $0)
#Logging.send(Logger::WARN, "warn", "tu_page.rb")
#Logging.send(Logger::ERROR, "error", "tu_page.rb")
#Logging.send(Logger::FATAL, "fatal", "tu_page.rb")
  def send(log_file, severity, message, line=nil, methode=nil, prog=nil)
    l = Logger.new(log_file, 'daily')
    case severity
      when Logger::INFO
      when Logger::WARN
      when Logger::ERROR, Logger::FATAL
        progname = (line.nil?) ? "_".ljust(5) : line.to_s
        progname += " | "
        progname += (methode.nil?) ? "_".ljust(5) : methode.to_s
        progname += " | "
        progname += (prog.nil?) ? "_".ljust(5) : prog
        puts "ENVOIE D UN MAIL" + message.to_s
      else
        p "code severity unknown #{severity}"
    end
    l.datetime_format = "%Y-%m-%d %H:%M:%S"
    l.formatter = proc { |severity, datetime, progname, msg| "#{datetime} | #{severity.ljust(5)} | #{message.ljust(80)} | #{progname}\n" }
    l.add(severity, message.force_encoding("UTF-8"), progname)
    l.close
  end


  module_function :send

end
#!/usr/bin/env ruby -w
# encoding: UTF-8
require "logger"
require File.dirname(__FILE__) + '/../lib/logging'

module Common
  SEPARATOR6 = "_"
  ARCHIVE = File.dirname(__FILE__) + "/../archive/"
  OUTPUT = File.dirname(__FILE__) + "/../output/"

  def information(msg)
    Logging.send($log_file, Logger::INFO, msg)
    p "#{Time.now.strftime("%Y-%m-%d %H:%M:%S")} => #{msg}"
  end

  def debug(msg, line=nil)
    Logging.send($log_file, Logger::DEBUG, msg, line)
  end

  def warning(msg, line=nil)
    Logging.send($log_file, Logger::WARN, msg, line)
    p "#{Time.now.strftime("%Y-%m-%d %H:%M:%S")} => #{msg}"
  end

  def alert(msg, line=nil)
    Logging.send($log_file, Logger::ERROR, msg, line)
    p "#{Time.now.strftime("%Y-%m-%d %H:%M:%S")} => #{msg}"
  end

  def error(msg, line=nil)
    Logging.send($log_file, Logger::ERROR, msg, line)
    p "#{Time.now.strftime("%Y-%m-%d %H:%M:%S")} ERROR => #{msg}"
  end

  def min(a, b)
    a < b ? a : b
  end

  def max(a, b)
    a > b ? a : b
  end

  module_function :min
  module_function :max
  module_function :information
  module_function :alert
  module_function :warning
  module_function :error
end
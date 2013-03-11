# coding: utf-8
require 'socket'
require 'json'
require 'json/ext'
require '../lib/logging'
require File.dirname(__FILE__) + '/../lib/common'
require File.dirname(__FILE__) + '/../model/authentification'
require 'logger'
require 'yaml'

class FTPDriver
  OUTPUT = File.dirname(__FILE__) + "/../output"
  @@log_file = File.dirname(__FILE__) + "/../log/" + File.basename(__FILE__, ".rb") + ".log"
  PARAMETERS = File.dirname(__FILE__) + "/../parameter/" + File.basename(__FILE__, ".rb") + ".yml"
  ENVIRONMENT= File.dirname(__FILE__) + "/../parameter/environment.yml"
  attr :user, :pwd, :authentification_server_port, :envir

  def initialize(driver_args=nil)
    @envir = driver_args unless driver_args.nil?
    @envir = "production" if driver_args.nil?
    load_parameters
  end
  def authenticate(user, pass, &block)
    @user = user
    @pwd = pass
    begin
      authen = Authentification.new(user, pass)
      check = authen.check(@authentification_server_port)
      Common.information("check authentification #{user}, #{pass} =>  #{check == true}")
      yield check == true
    rescue Exception => e
      Logging.send(@@log_file, Logger::ERROR, "FTPServer check authentification <#{user}:#{pass}> => #{e.message}")
    end

  end

  def get_file(path, &block)
    begin
      file = File.open(OUTPUT + path)
      Authentification.new(@user, @pwd).delete(@authentification_server_port)
      Common.information("push file <#{path}>")
      yield file
    rescue Exception => e
      Logging.send(@@log_file, Logger::ERROR, "FTPServer push file <#{path}> => #{e.message}")
    end
  end

  def change_dir(path, &block)
    yield false
  end

  def dir_contents(path, &block)
    yield false
  end

  def bytes(path, &block)
    yield false
  end

  def put_file(path, data, &block)
    yield false
  end

  def delete_file(path, &block)
    begin
      File.delete(OUTPUT + path)
      Common.information("delete file <#{path}>")
      Logging.send(@@log_file, Logger::INFO, "FTPServer delete file, #{path}")
      yield true
    rescue Exception => e
      Logging.send(@@log_file, Logger::ERROR, "FTPServer delete file, #{path} => #{e.message}")
      yield false
    end
  end

  def delete_dir(path, &block)
    yield false
  end

  def rename(from, to, &block)
    yield false
  end

  def make_dir(path, &block)
    yield false
  end

  private

  def dir_item(name)
    EM::FTPD::DirectoryItem.new(:name => name, :directory => true, :size => 0)
  end

  def file_item(name, bytes)
    EM::FTPD::DirectoryItem.new(:name => name, :directory => false, :size => bytes)
  end

  private
  def load_parameters()
    begin
      environment = YAML::load(File.open(ENVIRONMENT), "r:UTF-8")
      @envir = environment["staging"] unless environment["staging"].nil?
    rescue Exception => e
      Common.warning("loading parameter file #{ENVIRONMENT} failed : #{e.message}")
    end
    Common.information("environment : #{@envir}")
    begin
      params = YAML::load(File.open(PARAMETERS), "r:UTF-8")
      @authentification_server_port = params[@envir]["authentification_server_port"] unless params[@envir]["authentification_server_port"].nil?
    rescue Exception => e
      Logging.send(@@log_file, Logger::ERROR, "parameters file #{PARAMETERS} : #{e.message}")
    end
  end

end


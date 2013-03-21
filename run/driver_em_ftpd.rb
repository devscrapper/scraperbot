# coding: utf-8
require_relative '../lib/logging'
require_relative '../model/authentification'
require 'yaml'

class FTPDriver
  OUTPUT = File.dirname(__FILE__) + "/../output"
  @@log_file = File.dirname(__FILE__) + "/../log/" + File.basename(__FILE__, ".rb") + ".log"
  PARAMETERS = File.dirname(__FILE__) + "/../parameter/" + File.basename(__FILE__, ".rb") + ".yml"
  ENVIRONMENT= File.dirname(__FILE__) + "/../parameter/environment.yml"
  attr :user, :pwd, :authentification_server_port, :envir, :logger, :debugging

  def initialize(driver_args=nil)
    @envir = driver_args unless driver_args.nil?
    @envir = "production" if driver_args.nil?
    @debugging = false
    load_parameters
  end

  def authenticate(user, pass, &block)
    @user = user
    @pwd = pass
    begin
      authen = Authentification.new(user, pass)
      check = authen.check(@authentification_server_port)
      @logger.an_event.info "check authentification #{user}, #{pass} =>  #{check == true}"
      yield check == true
    rescue Exception => e
      @logger.an_event.error "FTPServer cannot check authentification <#{user}>"
      @logger.an_event.debug e
    end

  end

  def get_file(path, &block)
    begin
      file = File.open(OUTPUT + path)
      Authentification.new(@user, @pwd).delete(@authentification_server_port)
     @logger.an_event.info "push file <#{path}>"
      yield file
    rescue Exception => e
     @logger.an_event.error "FTPServer cannot push file <#{path}>"
      @logger.an_event.debug e
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
      @logger.an_event.info "delete file <#{path}>"
     @logger.an_event.debug "FTPServer delete file <#{path}>"
      yield true
    rescue Exception => e
      @logger.an_event.error "FTPServer cannot delete file <#{path}>"
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
      STDERR << "loading parameter file #{ENVIRONMENT} failed : #{e.message}"
    end

    begin
      params = YAML::load(File.open(PARAMETERS), "r:UTF-8")
      @authentification_server_port = params[@envir]["authentification_server_port"] unless params[@envir]["authentification_server_port"].nil?
      @debugging = params[@envir]["debugging"] unless params[@envir]["debugging"].nil?
    rescue Exception => e
      STDERR << "loading parameters file #{PARAMETERS} failed : #{e.message}"
    end
    @logger = Logging::Log.new(self, :staging => @envir, :debugging => @debugging)
    Logging::show_configuration
    logger.a_log.info "parameters of ftp server :"
    logger.a_log.info "authentification server port : #{@authentification_server_port}"
    logger.a_log.info "debugging : #{@debugging}"
    logger.a_log.info "staging : #{@envir}"
  end

end


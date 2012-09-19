# coding: utf-8
require 'socket'
require 'json'
require 'json/ext'
require '../lib/logging'
require 'logger'

class FTPDriver
  OUTPUT = File.dirname(__FILE__) + "/../output"
  @@log_file = File.dirname(__FILE__) + "/../log/" + File.basename(__FILE__, ".rb") + ".log"

  attr :user, :pwd, :authentification_server_port

  def authenticate(user, pass, &block)
    @user = user
    @pwd = pass

    begin
      @authentification_server_port= authentification_server_port
      s = TCPSocket.new 'localhost', @authentification_server_port
      s.puts JSON.generate({"who" => "ftpd", "cmd" => "check", "user" => user, "pwd" => pass})
      get_response = JSON.parse(s.gets)
      s.close
      Logging.send(@@log_file, Logger::INFO, "FTPServer check authentification #{user}, #{pass} => #{get_response["check"] == true}")
      yield get_response["check"] == true
    rescue Exception => e
      Logging.send(@@log_file, Logger::ERROR, "FTPServer check authentification #{user}, #{pass} => #{e.message}")
    end

  end

  def get_file(path, &block)
    begin
      file = File.open(OUTPUT + path)
      s = TCPSocket.new 'localhost', @authentification_server_port
      s.puts JSON.generate({"who" => "ftpd", "cmd" => "delete", "user" => @user, "pwd" => @pwd})
      s.close
      Logging.send(@@log_file, Logger::INFO, "FTPServer push file, #{path}")
      yield file
    rescue Exception => e
      Logging.send(@@log_file, Logger::ERROR, "FTPServer push file, #{path} => #{e.message}")
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
  def authentification_server_port()
     IO.readlines(File.dirname(__FILE__) + "/../config/config.rb").each { |line|
       return line.split("=")[1].gsub("\n","") if !line.split("=")[1].nil?

     }
  end

end


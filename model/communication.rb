require 'yaml'
require 'socket'
require File.dirname(__FILE__) + '/../lib/common'


class Communication
  include Common
  attr :data_go
  class CommunicationException < StandardError
  end

  def initialize(data_go)
    @data_go = YAML::dump data_go
  end

  def send_data_to(remote_ip="localhost", remote_port)
    begin
      s = TCPSocket.new remote_ip, remote_port
      s.puts @data_go
      local_port, local_ip = Socket.unpack_sockaddr_in(s.getsockname)
      Common.information("send data <#{@data_go}> from <#{local_ip}:#{local_port}> to <#{remote_ip}:#{remote_port}>")
    rescue Exception => e
      Common.alert("cannot send data <#{@data_go}> from <#{local_ip}:#{local_port}> to <#{remote_ip}:#{remote_port}> : #{e.message}")
      raise CommunicationException, e.message
    end
  end

end

class Information < Communication
  class InformationException < StandardError
  end

  def initialize(data_go)
    super(data_go)
  end

  def send_to(remote_ip="localhost", remote_port)
    begin
      send_data_to(remote_ip, remote_port)
    rescue Exception => e
      Common.alert("cannot send data <#{@data_go}> to <#{remote_ip}:#{remote_port}> : #{e.message}")
      raise InformationException, e.message
    end
  end
end

class Question < Communication
  attr :data_back

  class QuestionException < StandardError
  end

  def initialize(data_go)
    super(data_go)
  end

  def ask_to(remote_ip = "localhost", remote_port)
    begin
      s = TCPSocket.new remote_ip, remote_port
      s.puts @data_go
      local_port, local_ip = Socket.unpack_sockaddr_in(s.getsockname)
      Common.information("send data <#{@data_go}> from <#{local_ip}:#{local_port}> to <#{remote_ip}:#{remote_port}>")
    rescue Exception => e
      Common.alert("cannot send data <#{@data_go}> from <#{local_ip}:#{local_port}> to <#{remote_ip}:#{remote_port}> : #{e.message}")
      raise QuestionException, e.message
    end
    begin
      @data_back = ""
      while line = s.gets
        @data_back += "#{line}"
      end
      local_port, local_ip = Socket.unpack_sockaddr_in(s.getsockname)
      Common.information("response received <#{@data_back}> from <#{remote_ip}:#{remote_port}> to <#{local_ip}:#{local_port}>")
      s.close
    rescue Exception => e
      s.close
      Common.alert("response not received from <#{remote_ip}:#{remote_port}> to <#{local_ip}:#{local_port}> : #{e.message}")
      raise QuestionException, e.message
    end
    YAML::load @data_back
  end

end

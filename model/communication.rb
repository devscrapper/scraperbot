require 'yaml'
require 'socket'
require 'em-http-request'
require File.dirname(__FILE__) + '/../lib/common'


class Communication
  include Common
  attr :data_go_yaml,
       :data_go_hash,
       :data_go

  class CommunicationException < StandardError
  end

  def initialize(data_go)

    @data_go_yaml = YAML::dump data_go

    begin

      @data_go_hash = data_go.to_hash

    rescue

      @data_go_hash = nil

    end

    @data_go = data_go

  end

  def send_data_to_TCPSocket_server(remote_ip, remote_port)

    begin
      s = TCPSocket.new remote_ip, remote_port

      s.puts @data_go_yaml

      local_port, local_ip = Socket.unpack_sockaddr_in(s.getsockname)

    rescue Exception => e

      Common.alert("cannot send data <#{@data_go}> from <#{local_ip}:#{local_port}> to <#{remote_ip}:#{remote_port}> : #{e.message}")

      raise CommunicationException, e.message

    end
  end

  def send_data_to_http_server(remote_ip, remote_port, path)
    # le path doit commencer par /
    raise CommunicationException, "data <#{@data_go}> cannot be convert to a hash" if @data_go_hash.nil?
    uri = URI("http://#{remote_ip}:#{remote_port}#{path}")
    # si la fonction est utilisé dans un reactor il ne faut pas l'arreter
    dont_stop_reactor = EM.reactor_running?
    EventMachine.run {
      http = EventMachine::HttpRequest.new(uri).put :query => @data_go
      http.callback {EventMachine.stop unless dont_stop_reactor}
      http.errback {
        Common.alert ("cannot send data <#{@data_go}> to #{remote_ip}:#{remote_port}")
        EventMachine.stop unless dont_stop_reactor
        raise CommunicationException, "can not join #{remote_ip}:#{remote_port}"
      }
    }
  end
end

class Information < Communication
  class InformationException < StandardError
  end

  def initialize(data_go)
    super(data_go)
  end

  def send_local(remote_port, options=nil)
    send_to("localhost", remote_port, options)
  end

  def send_to(remote_ip, remote_port, options=nil)

    begin
      send_data_to_TCPSocket_server(remote_ip, remote_port) if options.nil?
      send_data_to_http_server(remote_ip, remote_port, options["path"]) if !options.nil? and options["scheme"] == "http"
      Common.debug("send Information <#{@data_go}> to <#{remote_ip}:#{remote_port}>")
    rescue Exception => e
      Common.alert("cannot send Information <#{@data_go}> to <#{remote_ip}:#{remote_port}> : #{e.message}")
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
      s.puts @data_go_yaml
      local_port, local_ip = Socket.unpack_sockaddr_in(s.getsockname)
      Common.debug("ask Question <#{@data_go}> to <#{remote_ip}:#{remote_port}>")
    rescue Exception => e
      Common.alert("ask Question <#{@data_go}> to <#{remote_ip}:#{remote_port}> failed : #{e.message}")
      raise QuestionException, e.message
    end
    begin
      @data_back = ""
      while (line = s.gets)
        @data_back += "#{line}"
      end
      local_port, local_ip = Socket.unpack_sockaddr_in(s.getsockname)
      Common.information("Response received <#{@data_back}> from <#{remote_ip}:#{remote_port}>")
      s.close
    rescue Exception => e
      s.close
      Common.alert("Response not received from <#{remote_ip}:#{remote_port}> to <#{local_ip}:#{local_port}> : #{e.message}")
      raise QuestionException, e.message
    end
    YAML::load @data_back
  end

end


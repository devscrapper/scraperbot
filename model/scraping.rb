class Scraping
  attr :label,
       :connection, #la connection creee par le serveur
       :log_file

  def initialize(connection, label)
    @label = label
    # url = nil si et seulement si on renvoit tous les fichiers de l'OUTPUT préfixé par le nom de la classe
    @connection = connection
    @log_file = File.dirname(__FILE__) + "/../log/" + self.class.to_s + ".log"
  end

  def get_authentification
    begin
      s = TCPSocket.new 'localhost', @connection.authentification_server_port
      s.puts JSON.generate({"who" => self.class.name, "cmd" => "get"})
      get_response = JSON.parse(s.gets)
      port, ip = Socket.unpack_sockaddr_in(s.getsockname)
      Logging.send(@log_file, Logger::INFO, "ask new authentification from  #{ip}:#{port} to 'localhost':#{@connection.authentification_server_port}")
      Logging.send(@log_file, Logger::DEBUG, "new authentification #{get_response} from  #{ip}:#{port} to 'localhost':#{@connection.authentification_server_port}")
      s.close
    rescue Exception => e
      Logging.send(@log_file, Logger::ERROR, "ask new authentification from  localhost':#{@connection.authentification_server_port} failed")
    end
    get_response
  end

end
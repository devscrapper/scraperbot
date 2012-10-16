module Exchange_file
  OUTPUT = File.dirname(__FILE__) + "/../output/"
  EOF_ROW = "%EOFL%"

  attr :today, #date du jour du premier volume => eviter que les fichiers n'aient pas la meme date
       :volume, #numero du fichier
       :f  #fichier contenant les donn�es

  def new_volume_output_file()
    if @f.nil?
      @volume = 1
    else
      @f.close
      @volume += 1
    end
    @f = File.open(OUTPUT + "#{self.class}-#{@label}-#{@today}-#{@volume}.txt", "w:utf-8")
    @f.sync  = true
  end
  def delete_all_output_files()
  Logging.send(@log_file, Logger::INFO, "deleting all files #{self.class}-#{@label}* ")
   Dir.entries(OUTPUT).each { |file|
     File.delete(OUTPUT + file) if File.fnmatch("#{self.class}-#{@label}*", file)
   }
  end

  def push_file(id_file)

    begin
      response = get_authentification
      s = TCPSocket.new @connection.load_server_ip, @connection.load_server_port
      port, ip = Socket.unpack_sockaddr_in(s.getsockname)
      data = {"who" => self.class.name, "where" => ip, "cmd" => "file", "label" => @label, "date_scraping" => @today, "id_file" => id_file, "user" => response["user"], "pwd" => response["pwd"]}
      Logging.send(@log_file, Logger::DEBUG, "push file #{data}")
      s.puts JSON.generate(data)

      Logging.send(@log_file, Logger::INFO, "push file #{id_file} from #{ip}:#{port} to #{@connection.load_server_ip}:#{@connection.load_server_port}")

      s.close
    rescue Exception => e
      Logging.send(@log_file, Logger::ERROR, "push file #{id_file} failed to #{@connection.load_server_ip}:#{@connection.load_server_port} : #{e.message} : #{e.backtrace}")
    end

  end

  def send_all_files()
      w = self
      @push_file_spawn = EM.spawn { |id_file|
        w.push_file(id_file)
      }
      port, ip = Socket.unpack_sockaddr_in(connection.get_peername)
      begin
        Logging.send(@log_file, Logger::INFO, "send all files to #{ip}:#{port}")
        Dir.entries(OUTPUT).each { |file|
          Logging.send(@log_file, Logger::INFO, "#{file}") if File.fnmatch("#{self.class.name}*.txt", file)
          @push_file_spawn.notify file if File.fnmatch("#{self.class.name}*.txt", file)
        }
      rescue Exception => e
        Logging.send(@log_file, Logger::ERROR, "send all files #{e.message} to #{port}:#{ip}")
      end
    end
end
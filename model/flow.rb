require 'net/ftp'
require_relative 'communication'
require_relative '../lib/logging'

class Flow
  class FlowException < StandardError;
  end

  MAX_SIZE = 1000000 # taille max d'un volume
  SEPARATOR = "_" # separateur entre elemet composant (type_flow, label, date, vol) le nom du volume (basename)
  ARCHIVE = File.dirname(__FILE__) + "/../archive/" #localisation du repertoire d'archive
  FORBIDDEN_CHAR = /[_ ]/ # liste des caractères interdits dans le typeflow et label d'un volume
  attr :descriptor,
       :dir,
       :type_flow,
       :label,
       :date,
       :vol,
       :ext,
       :logger


  #----------------------------------------------------------------------------------------------------------------
  # class methods
  #----------------------------------------------------------------------------------------------------------------

  def self.from_basename(dir, basename)
    ext = File.extname(basename)
    basename = File.basename(basename, ext)
    basename_splitted = basename.split(SEPARATOR)
    type_flow = basename_splitted[0]
    label = basename_splitted[1]
    date = basename_splitted[2]
    vol = basename_splitted[3]

    Flow.new(dir, type_flow, label, date, vol, ext)
  end

  def self.from_absolute_path(absolute_path)
    dir = File.dirname(absolute_path)
    basename = File.basename(absolute_path)
    Flow.from_basename(dir, basename)
  end

#----------------------------------------------------------------------------------------------------------------
# instance methods
#----------------------------------------------------------------------------------------------------------------

  def initialize(dir, type_flow, label, date, vol=nil, ext=".txt")
    @dir = dir
    @type_flow = type_flow.gsub(FORBIDDEN_CHAR, "-") #le label ne doit pas contenir les caractères interdits
    @label = label.gsub(FORBIDDEN_CHAR, "-") #le label ne doit pas contenir les caractères interdits
    @date = date.strftime("%Y-%m-%d") if date.is_a?(Date)
    @date = date unless date.is_a?(Date)
    @vol = vol.to_s unless vol.nil?
    @ext = ext
    @logger = Logging::Log.new(self, :staging => $staging, :debugging => $debugging)
    if  !(@dir && @type_flow && @label && @date && @ext) and $debugging
      @logger.an_event.debug "dir <#{dir}>"
      @logger.an_event.debug "type_flow <#{type_flow}>"
      @logger.an_event.debug "label <#{label}>"
      @logger.an_event.debug "date <#{date}>"
      @logger.an_event.debug "vol <#{vol}>"
      @logger.an_event.debug "ext <#{ext}>"
      @logger.an_event.debug "details flow <#{self.to_s}>"

    end
    raise FlowException, "Flow not initialize" unless @dir && @type_flow && @label && @date && @ext

  end

  def vol=(vol)
    @vol = vol.to_s
  end

  def absolute_path
    File.join(@dir, basename)
  end

  def basename
    basename = @type_flow + SEPARATOR + @label + SEPARATOR + @date
    basename += SEPARATOR + @vol unless @vol.nil?
    basename += @ext
    basename
  end


  def write(data)
    @descriptor = File.open(absolute_path, "w:UTF-8") if @descriptor.nil?
    @descriptor.sync = true
    @descriptor.write(data)
  end

  def append(data)
    @descriptor = File.open(absolute_path, "a:UTF-8") if @descriptor.nil?
    @descriptor.sync = true
    @descriptor.write(data)
  end

  def rewind()
    raise FlowException, "Flow <#{absolute_path}> not exist" unless exist?
    @descriptor = File.open(absolute_path, "r:UTF-8") if @descriptor.nil?
    @descriptor.rewind
  end

  def close
    @descriptor.close unless @descriptor.nil?
    @descriptor = nil
  end

  def empty
    @descriptor = File.open(absolute_path, "w:BOM|UTF-8:-") if @descriptor.nil?
    write("")
  end

  def size
    @descriptor = File.open(absolute_path, "r:BOM|UTF-8:-") if @descriptor.nil?
    @descriptor.size
  end

  def count_lines(eofline)
    raise FlowException, "Flow <#{absolute_path}> not exist" unless exist?
    File.foreach(absolute_path, eofline, encoding: "BOM|UTF-8:-").inject(0) { |c| c+1 }
  end

  def total_lines(eofline)
    total_lines = 0
    volumes.each { |flow| total_lines += flow.count_lines(eofline) }
    total_lines
  end

  def descriptor
    raise FlowException, "Flow <#{absolute_path}> not exist" unless exist?
    @descriptor = File.open(absolute_path, "r:BOM|UTF-8:-") if @descriptor.nil?
    @descriptor
  end

  def readline
    raise FlowException, "Flow <#{absolute_path}> not exist" unless exist?
    @descriptor = File.open(absolute_path, "BOM|UTF-8:-") if @descriptor.nil?
    @descriptor.readline()
  end

  def exist?
    File.exist?(absolute_path)
  end

  def delete
    File.delete(absolute_path) if exist?
  end

  def cp(to_path)
    raise FlowException, "target <#{to_path}> is not valid" unless File.exists?(to_path) && File.directory?(to_path)
    raise FlowException, "Flow <#{absolute_path}> not exist" unless exist?
    FileUtils.cp(absolute, to_path)
  end

  def last()
    return basename if exist?
    volum = "#{SEPARATOR}#{@vol}" unless @vol.empty?
    volum = "" if @vol.empty?
    max_time = Time.new(2001, 01, 01)
    chosen_file = nil
    Dir.glob("#{@dir}#{@type_flow}#{SEPARATOR}#{@label}#{SEPARATOR}*#{volum}#{@ext}").each { |file|
      if File.ctime(file) > max_time
        max_time = File.ctime(file)
        chosen_file = file
      end
    }
    chosen_file
  end

  def archive()
    # archive le flow courant : deplace le fichier dans le repertoire ARCHIVE
    raise FlowException, "Flow <#{absolute_path}> not exist" unless exist?
    FileUtils.mv(absolute_path, ARCHIVE, :force => true)
  end

  def archive_previous
    # N'ARCHIVE PAS L'INSTANCE COURANTE
    # archive le flow ou les flows qui sont antérieurs à l'instance courante
    # l'objectif est de faire le ménage dans le répertoire qui contient l'instance courante
    # le ou les flow sont déplacés dans ARCHIVE

  end

  def volumes
    #renvoi un array contenant les flow de tous les volumes
    raise FlowException, "Flow <#{absolute_path}> not exist" unless exist?

    return [self] if @vol.empty? # si le flow n'a pas de volume alors renvoi un tableau avec le flow

    array = []
    crt = self
    vol = 1
    crt.vol = vol
    while crt.exist?
      array << crt
      crt = Flow.from_absolute_path(crt.absolute_path)
      vol += 1
      crt.vol = vol
    end
    array
  end

  def volumes?
    #renvoi le nombre de volume
    raise FlowException, "Flow <#{absolute_path}> not exist" unless exist?
    return 0 if @vol.empty? # si le flow n'a pas de volume alors renvoi 0
    count = 0
    crt = self
    vol = 1
    crt.vol = vol
    while crt.exist?
      count += 1
      crt = Flow.from_absolute_path(crt.absolute_path)
      vol += 1
      crt.vol = vol
    end
    count
  end

  def put(ip_to, port_to, port_ftp_server, user, pwd, last_volume = false)
    data = {
        "type_flow" => @type_flow,
        "data" => {"port_ftp_server" => port_ftp_server,
                   "user" => user,
                   "pwd" => pwd,
                   "basename" => basename,
                   "last_volume" => last_volume}
    }
    begin
      Information.new(data).send_to(ip_to, port_to)
      @logger.an_event.debug "send properties flow <#{basename}> to #{ip_to}:#{port_to}"
    rescue Exception => e
      @logger.an_event.error "cannot send properties flow <#{basename}> to #{ip_to}:#{port_to}"
      @logger.an_event.debug e
      raise FlowException, e.message
    end
  end

  def get(ip_from, port_from, user, pwd)
    begin
      ftp = Net::FTP.new
      ftp.connect(ip_from, port_from)
      ftp.login(user, pwd)
      ftp.gettextfile(basename, absolute_path)
      ftp.delete(basename)
      ftp.close
      @logger.an_event.debug "get flow <#{basename}> from #{ip_from}:#{port_from}"
    rescue Exception => e
      @logger.an_event.error "cannnot get flow <#{basename}> from #{ip_from}:#{port_from}"
      @logger.an_event.debug e
      raise FlowException, e.message
    end
  end

  def push(authentification_server_port,
      input_flows_server_ip,
      input_flows_server_port,
      ftp_server_port,
      vol = nil,
      last_volume = false)

    if @vol.empty?

      # le flow n'a pas de volume => on pousse le flow vers sa destination  et last_volume= true
      begin
        push_vol(authentification_server_port,
                 input_flows_server_ip,
                 input_flows_server_port,
                 ftp_server_port,
                 true)
        @logger.an_event.debug "push flow <#{basename}> to input_flow server #{input_flows_server_ip}:#{input_flows_server_port}"
      rescue Exception => e
        @logger.an_event.error "cannot push flow <#{basename}> to input_flow server #{input_flows_server_ip}:#{input_flows_server_port}"
        @logger.an_event.debug e
        raise FlowException
      end
    else
      # le flow a des volumes

      if vol.nil?

        # aucune vol n'est précisé donc on pousse tous les volumes en commancant du premier même si le flow courant n'est pas le premier,
        #en précisant pour le dernier le lastvolume = true
        count_volumes = volumes?

        volumes.each { |volume|
          begin
            volume.push_vol(authentification_server_port,
                            input_flows_server_ip,
                            input_flows_server_port,
                            ftp_server_port,
                            count_volumes == volume.vol.to_i)
            @logger.an_event.debug "push vol <#{volume.vol.to_i}> of flow <#{basename}> to input_flow server #{input_flows_server_ip}:#{input_flows_server_port}"
          rescue Exception => e
            @logger.an_event.error "cannot push vol <#{volume.vol.to_i}> of flow <#{basename}> to input_flow server #{input_flows_server_ip}:#{input_flows_server_port}"
            @logger.an_event.debug e
            raise FlowException
          end
        }

      else

        # on pousse le volume précisé
        # si lastvolume n'est pas précisé alors = false
        @vol = vol
        raise FlowException, "volume <#{@vol}> of the flow <#{basename}> do not exist" unless exist? # on verifie que le volume passé existe
        begin
          push_vol(authentification_server_port,
                   input_flows_server_ip,
                   input_flows_server_port,
                   ftp_server_port,
                   last_volume)
        rescue Exception => e
          @logger.an_event.error "push vol <#{@vol}> of flow <#{basename}> to input_flow server #{input_flows_server_ip}:#{input_flows_server_port} failed"
          @logger.an_event.debug e
          raise FlowException
        end
      end

    end

  end


  def push_vol(authentification_server_port,
      input_flows_server_ip,
      input_flows_server_port,
      ftp_server_port,
      last_volume = false)

    begin
      authen = Authentification.get_one(authentification_server_port)
      @logger.an_event.info "ask a new authentification"
    rescue Exception => e
      @logger.an_event.error "cannot ask a new authentification to localhost:#{authentification_server_port}"
      @logger.an_event.debug e
      raise FlowException
    end

    begin
      put(input_flows_server_ip,
          input_flows_server_port,
          ftp_server_port,
          authen.user,
          authen.pwd,
          last_volume)

    rescue Exception => e

      raise FlowException
    end

  end

  def new_volume()
    raise FlowException, "Flow <#{absolute_path}> has no first volume" if @vol.empty?
    close
    Flow.new(@dir, @type_flow, @label, @date, @vol.to_i + 1, @ext)
  end
end
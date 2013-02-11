require 'socket'
require File.dirname(__FILE__) + '/../lib/common'
require File.dirname(__FILE__) + '/../model/communication'

class Flow
  class FlowException < StandardError;
  end
  include Common
  MAX_SIZE = 1000000
  SEPARATOR = "_"
  ARCHIVE = File.dirname(__FILE__) + "/../archive/"

  attr :descriptor,
       :dir,
       :type_flow,
       :label,
       :date,
       :vol,
       :ext

  #TODO publier la version vers les autres
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
    @type_flow = type_flow
    @label = label
    @date = date.strftime("%Y-%m-%d") if date.is_a?(Date)
    @date = date unless date.is_a?(Date)
    @vol = vol.to_s
    @ext = ext
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
    basename += SEPARATOR + @vol unless @vol.empty?
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
    @descriptor.write(data)
  end

  def close
    @descriptor.close unless @descriptor.nil?
  end

  def size
    @descriptor = File.open(absolute_path, "r:UTF-8") if @descriptor.nil?
    @descriptor.size
  end

  def count_lines(eofline)
    raise FlowException, "Flow <#{absolute_path}> not exist" unless exist?
    File.foreach(absolute_path, eofline, encoding: "BOM|UTF-8:-").inject(0) { |c| c+1 }
  end

  def descriptor
    raise FlowException, "Flow <#{absolute_path}> not exist" unless exist?
    @descriptor = File.open(absolute_path, "BOM|UTF-8:-") if @descriptor.nil?
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

  def archive
    raise FlowException, "Flow <#{absolute_path}> not exist" unless exist?
    FileUtils.mv(absolute_path, ARCHIVE, :force => true)
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
        "port_ftp_server" => port_ftp_server,
        "user" => user,
        "pwd" => pwd,
        "type_flow" => @type_flow,
        "basename" => basename,
        "last_volume" => last_volume,
    }
    begin
      Information.new(data).send_to(ip_to, port_to)
    rescue Exception => e
      alert("put flow <#{basename}> to #{ip_to}:#{port_to} failed : #{e.message}")
      raise FlowException
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
    rescue Exception => e
      alert("get flow <#{basename}> from #{ip_from}:#{port_from} failed : #{e.message}")
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
      push_vol(authentification_server_port,
               input_flows_server_ip,
               input_flows_server_port,
               ftp_server_port,
               true)
    else
      # le flow a des volumes

      if vol.nil?

        # aucune vol n'est précisé donc on pousse tous les volumes en commancant du premier même si le flow courant n'est pas le premier,
        #en précisant pour le dernier le lastvolume = true
        count_volumes = volumes?

        volumes.each { |volume|

          volume.push_vol(authentification_server_port,
                          input_flows_server_ip,
                          input_flows_server_port,
                          ftp_server_port,
                          count_volumes == volume.vol.to_i) }

      else

        # on pousse le volume précisé
        # si lastvolume n'est pas précisé alors = false
        @vol = vol
        raise FlowException, "volume <#{@vol}> of the flow <#{basename}> do not exist" unless exist? # on verifie que le volume passé existe
        push_vol(authentification_server_port,
                 input_flows_server_ip,
                 input_flows_server_port,
                 ftp_server_port,
                 last_volume)
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

    rescue Exception => e

      alert("push flow <#{basename}> failed, because new authentification to localhost:#{authentification_server_port} failed : #{e.message}")
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
      alert("push flow <#{basename}> failed, because send properties of flow to input_flow_server (#{input_flows_server_ip}:#{input_flows_server_port}) failed : #{e.message}")
      raise Scraping_google_analyticsException
    end

  end

  def new_volume()
    raise FlowException, "Flow <#{absolute_path}> has no first volume" if @vol.empty?
    close
    Flow.new(@dir, @type_flow, @label, @date, @vol.to_i + 1, @ext)
  end
end
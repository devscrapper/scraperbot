module Tasking
  PARAMETERS = File.dirname(__FILE__) + "/../../parameter/tasks_server.yml"
  ENVIRONMENT= File.dirname(__FILE__) + "/../../parameter/environment.yml"

  class Task
    attr :tasks_server_port,
         :cmd,
         :data,
         :logger


    def initialize(cmd, data)
      @cmd = cmd
      @data = data
      @tasks_server_port = 9151
      begin
        environment = YAML::load(File.open(ENVIRONMENT), "r:UTF-8")
        staging = environment["staging"] unless environment["staging"].nil?
      rescue Exception => e
        STDERR << "loading parameter file #{ENVIRONMENT} failed : #{e.message}"
      end

      begin
        params = YAML::load(File.open(PARAMETERS), "r:UTF-8")
        p environment
        @tasks_server_port = params[staging]["tasks_server_port"] unless params[staging]["tasks_server_port"].nil?
      rescue Exception => e
        STDERR << "loading parameters file #{PARAMETERS} failed : #{e.message}"
      end

      @logger = Logging::Log.new(self, :staging => $staging, :debugging => $debugging)

    end

    def execute()
      begin
        Information.new({"cmd" => @cmd,
                         "data" => @data}).send_local(@tasks_server_port)
        @logger.an_event.info "ask execution task <#{@cmd}> to tasks server"
      rescue Exception => e
        @logger.an_event.error "cannot ask execution task <#{@cmd}> to tasks server"
        @logger.an_event.debug e
        raise EventException, "cannot ask execution task <#{@cmd}> to tasks server because #{e}"
      end
    end
  end
end
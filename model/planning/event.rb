require 'rubygems'
require 'eventmachine'
require 'ice_cube'
require 'json'
require_relative '../communication'

module Planning
  class Event
    class EventException < StandardError
    end
    EXECUTE_ALL = "execute_all"
    EXECUTE_ONE = "execute_one"
    SAVE = "save"
    DELETE = "delete"

    attr :key,
         :periodicity,
         :cmd,
         :business


    def initialize(key, cmd, periodicity=nil, business=nil)
      @key = key
      @cmd = cmd
      @periodicity = periodicity
      @business = business
    end

    def to_json(*a)
      {
          "key" => @key,
          "cmd" => @cmd,
          "periodicity" => @periodicity,
          "business" => @business
      }.to_json(*a)
    end

    def to_display()

    end

    def to_s(*a)
      {
          "key" => @key,
          "cmd" => @cmd,
      }.to_s(*a)
    end

    def execute(load_server_port)
      begin
        data = {
            "cmd" => @cmd,
            "label" => @business["label"],
            "date_building" => @key["building_date"] || Date.today,
            "data" => @business}

        Information.new(data).send_local(load_server_port)
      rescue Exception => e
        raise EventException, "cannot execute event <#{@cmd}> for <#{@business["label"]}> because #{e}"
      end
    end
  end


end
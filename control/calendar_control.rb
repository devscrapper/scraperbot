#!/usr/bin/env ruby -w
# encoding: UTF-8
require 'rubygems' # if you use RubyGems   
require 'daemons'

application = "calendar"
options = {
  :app_name   => "#{application}_server",
  :ARGV       => [ARGV[0], "--ontop", "--","--envir=#{ARGV[1]}"],
  :dir_mode   => :script,
  :dir        => './',
  :multiple   => false,
  :ontop      => true,
  :mode       => :load,
  :backtrace  => true,
  :monitor    => true
}

Daemons.run(File.join(File.dirname(__FILE__), "../run/#{application}_server.rb"), options)

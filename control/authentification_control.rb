#!/usr/bin/env ruby -w
# encoding: UTF-8
require 'rubygems' # if you use RubyGems   
require 'daemons'


options = {
  :app_name   => "authentification_server",
  :ARGV       => ["start", "--ontop", "--","--envir=#{ARGV[0]}"],
  :dir_mode   => :script,
  :dir        => './',
  :multiple   => false,
  :ontop      => true,
  :mode       => :load,
  :backtrace  => true,
  :monitor    => true
}

Daemons.run(File.join(File.dirname(__FILE__), '../run/authentification_server.rb'), options)

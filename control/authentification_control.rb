#!/usr/bin/env ruby -w
# encoding: UTF-8
require 'rubygems' # if you use RubyGems   
require 'daemons'


Daemons.run('../run/authentification_server.rb')
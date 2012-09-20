require 'rubygems'
require 'eventmachine'
require 'em-http'
require 'json'
require 'json/ext'
require 'date'
require 'method_profiler'
require  File.dirname(__FILE__) + '/../model/website.rb'

profiler = MethodProfiler.observe(Website)


EventMachine.run {
my_obj = Website.new("http://localhost:81/my%20portable%20files/")

options = Hash.new
my_obj.scrape(options)

 }

puts profiler.report
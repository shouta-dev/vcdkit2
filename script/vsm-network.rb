#!/usr/bin/env ruby
#######################################################################################
#
# Copyright 2011 Kaoru Fukumoto All Rights Reserved
#
# You may freely use and redistribute this script as long as this 
# copyright notice remains intact 
#
#
# DISCLAIMER. THIS SCRIPT IS PROVIDED TO YOU "AS IS" WITHOUT WARRANTIES OR CONDITIONS 
# OF ANY KIND, WHETHER ORAL OR WRITTEN, EXPRESS OR IMPLIED. THE AUTHOR SPECIFICALLY 
# DISCLAIMS ANY IMPLIED WARRANTIES OR CONDITIONS OF MERCHANTABILITY, SATISFACTORY 
# QUALITY, NON-INFRINGEMENT AND FITNESS FOR A PARTICULAR PURPOSE. 
#
#######################################################################################
require 'optparse'
require 'vcdkit'

#
# Process command args
#
options={
}

$log = VCloud::Logger.new

optparse = OptionParser.new do |opt|
  opt.banner = "Usage: vsm-network.rb [options]"

  vsmopts(options,opt)

  opt.on('-h','--help','Display this help') do
    puts optparse
    exit
  end
end

begin
  optparse.parse!
rescue SystemExit => e
  exit(e.status)
rescue Exception => e
  puts e
  puts optparse
  exit 1
end

begin
  vsm = VShieldManager::VSM.new
  vsm.connect(*options[:vsm])
  vsm.each_vse do |vse|
    begin
      vse.serviceStats
      $log.info("Confirmed vShield Edge '#{vse.name}' is running")
    rescue Exception => e      
      $log.error("Failed to retrieve service status from vShield Edge '#{vse.name}': #{e}")
    end
  end

rescue Exception => e
  $log.error("vsm-network failed: #{e}")
  $log.error(e.backtrace)
  exit 1
end

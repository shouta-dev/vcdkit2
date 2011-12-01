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

optparse = OptionParser.new do |opt|
  opt.banner = "Usage: vcb-report.rb [options]"

  opt.on('-c','--cb HOST,USER',Array,'Chargeback login parameters') do |o|
    case o[0]
    when "1"
      options[:cb] = cb1
    when "2"
      options[:cb] = cb2
    else
      options[:cb] = o
    end
  end

  opt.on('-n','--name REPORT_NAME_PATTERN','Export report by name') do |o|
    options[:name] = o
  end

  opt.on('-l','--logfile LOGFILEPATH','Log file name') do |o|
    options[:logfile] = o
  end

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

#
# MAIN
#
$log = VCloud::Logger.new

begin
  vcb = Chargeback::VCB.new
  vcb.connect(*options[:cb])
  vcb.searchReport(options[:name]).each do |id|
    vcb.exportReport(id)
  end

rescue Exception => e
  $log.error("vcb-report failed: #{e}")
  $log.error(e.backtrace)
  exit 1
end

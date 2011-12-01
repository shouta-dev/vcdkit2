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
$: << File.dirname(__FILE__) + "/../lib"
require 'rubygems'
require 'highline/import'
require 'optparse'
require 'vcdkit'

options = {}
$log = VCloud::Logger.new

optparse = OptionParser.new do |opt|
  opt.banner = "Usage: vcd-pass.rb [options]"

  opt.on('-v','--vcd','Change login password for vCloud Director') do |o|
    options[:apps] << {:name => 'vCloud Director', :file => '.vcd'}
  end
  opt.on('-c','--vcenter','Change login password for vCenter') do |o|
    options[:apps] << {:name => 'vCenter', :file => '.vc'}
  end
  opt.on('-e','--esx','Change login password for ESX') do |o|
    options[:apps] << {:name => 'ESX', :file => '.esx'}
  end
  opt.on('-b','--chargeback','Change login password for vCenter Chargeback') do |o|
    options[:apps] << {:name => 'vCenter Chargeback', :file =>'.vcb'}
  end
  opt.on('','--chargeback_db','Change login password for vCenter Chargeback DB') do |o|
    options[:apps] << {:name => 'vCenter Chargeback DB', :file =>'.vcbdb'}
  end
  opt.on('-s','--vsm','Change login password for vShield Manager') do |o|
    options[:apps] << {:name => 'vShield Manager', :file =>'.vsm'}
  end

  VCloud::Logger.parseopts(opt)

  opt.on('-h','--help','Display this help') do
    puts optparse
    exit
  end
end

begin
  optparse.parse!
  if (options[:apps].size == 0)
    raise OptionParser::MissingArgument.new("Applications")
  end
rescue SystemExit => e
  exit(e.status)
rescue Exception => e
  puts e
  puts optparse
  exit 1
end

options[:apps].each do |a|
  p = ask("Enter #{a[:name]} password: "){|q| q.echo = '*'}
  open(a[:file],'w'){|f| f.puts VCloud::SecurePass.new().encrypt(p)}
  $log.warn("Password for #{a[:name]} has been changed")
end

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
require 'optparse'
require 'vcdkit'

options={}

$log = VCloud::Logger.new
$mail = VCloud::Mailer.new

optparse = OptionParser.new do |opt|
  opt.banner = "Usage: vcd-ex.rb [options]"

  VCloud::Logger.parseopts(opt)
  VCloud::Mailer.parseopts(opt)

  opt.on('-h','--help','Display this help') do
    puts opt
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
  vcd = VCloud::VCD.new($log)
  vcd.connect(VCloudServers.default('vCD'))

rescue Exception => e
  $log.error("vcd-ex failed: #{e}")
  $log.error(e.backtrace)

ensure
  if($log.errors>0 && $log.temp)
    # following local variables can be accessable from inside
    # mailer conf templates via binding
    vcdhost = options[:vcd][0]
    hostname = `hostname`.chomp
    now = Time.now
    $mail.send({'vcd-ex.log' => File.read($log.temp.path)},
               binding)
  end
end
exit ($log.errors + $log.warns)

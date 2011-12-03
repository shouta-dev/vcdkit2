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

options={
  :tree => Time.now.strftime('%Y-%m-%d_%H-%M-%S'),
  :dir => "#{$VCDKIT}/data/vcd-dump",
  :target => :all,
}

$log = VCloud::Logger.new
$mail = VCloud::Mailer.new

optparse = OptionParser.new do |opt|
  opt.banner = "Usage: vcd-dump.rb [options]"

  opt.on('-A','--all','Dump all data') do |o|
    options[:target] = :all
  end
  opt.on('-a','--vapp ORG,VDC,VAPP',Array,'Dump specified vApp data') do |o|
    options[:target] = o
  end
  opt.on('-o','--org ORG',Array,'Dump specified organization data') do |o|
    options[:target] = o
  end

  opt.on('-t','--tree TREENAME',Array,'Dump tree directory name') do |o|
    options[:tree] = o
  end

  VCloud::Logger.parseopts(opt)
  VCloud::Mailer.parseopts(opt)

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
  vcd = VCloud::VCD.new($log)
  vcd.connect(*VCloudServers.default('vCD'))

  vc = VSphere::VCenter.new($log)
  vc.connect(*VCloudServers.default('vCenter'))

  ot = options[:target]
  dir = "#{options[:dir]}/#{options[:tree]}"
  if(ot == :all)
    vcd.save(dir)
    vc.save(dir)
  elsif(ot.size == 1)
    vcd.org(ot[0]).save(dir)
  elsif(ot.size == 3)
    vcd.org(ot[0]).vdc(ot[1]).vapp(ot[2]).save(dir)
  end

rescue Exception => e
  $log.error("vcd-dump failed: #{e}")
  e.backtrace.each {|l| $log.error(l)}
  exit 1
ensure
  if($log.errors>0 && $log.temp)
    # following local variables can be accessable from inside
    # mailer conf templates via binding
    vcdhost = options[:vcd][0]
    hostname = `hostname`.chomp
    now = Time.now
    $mail.send({'vcd-dump.log.gz' => File.read($log.compressed_temp)},
               binding)
  end
  exit($log.errors + $log.warns)
end

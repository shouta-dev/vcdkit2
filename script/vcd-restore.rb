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
require 'yaml'
require 'vcdkit'

#
# Process command args
#
options = {
  :input => "#{$VCDKIT}/data/vcd-dump",
  :output => "#{$VCDKIT}/data/vcd-report",
  :vcd => $VCD[0]
}

$log = VCloud::Logger.new

optparse = OptionParser.new do |opt|
  opt.banner = "Usage: vcd-report.rb CMD [cmd-options]"

  vcdopts(options,opt)
  
  opt.on('-i','--input DIR','Root directory of the vCD dump data') do |o|
    options[:input] = o
  end
  opt.on('-t','--tree TREENAME',Array,'Directory name to identify dump tree') do |o|
    options[:tree] = o
  end

  opt.on('-o','--output DIR','Specify directory for reports') do |o|
    options[:output] = o
  end

  opt.on('-a','--vapp ORG,VDC,VAPP',Array,'Restore source vApp') do |o|
    options[:src] = o
  end

  opt.on('-s','--skip','Skip interactive questions') do |o|
    options[:skip] = true
  end

  VCloud::Logger.parseopts(opt)

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

if(options[:tree].nil?)
  begin
    pattern = "*"
    while true
      choose do |menu|
        menu.header = 'Select restart target directory'
        Dir.glob("#{options[:input]}/#{pattern}").sort.each do |d|
          next unless File.directory?(d)
          tree = File.basename(d)
          next if tree == 'archive'
          menu.choice(tree) {options[:tree] = tree; raise "BREAK"}
        end
        menu.choice("Specify date") {
          pattern = ask("Date: ",Date).strftime('%Y-%m-%d*')
        }
        menu.choice("Change name pattern. Current pattern='#{pattern}'") {
          pattern = ask("New pattern: ")
        }
      end
    end
  rescue Exception => e
  end

  options[:src] = [nil,nil,nil]
  begin
    pattern = "*" + ask("Enter vApp name pattern: ") + "*"
    while true
      choose do |menu|
        menu.header = 'Select VAPP'
        Dir.glob("#{options[:input]}/#{options[:tree]}/" +
                 "ORG/*/VDC/*/VAPP/#{pattern}").sort.each do |d|
          next unless File.directory?(d)

          d =~ /ORG\/(.+)\/VDC\/(.+)\/VAPP\/.+/
          org=$1; vdc=$2
          vapp = File.basename(d)
          menu.choice("#{org} | #{vdc} | #{vapp}") do
            options[:src][0] = org
            options[:src][1] = vdc
            options[:src][2] = vapp
            raise "BREAK"
          end
        end
        menu.choice("Change name pattern. Current pattern='#{pattern}'") {
          pattern = "*" + ask("New pattern: ") + "*"
        }
      end
    end
  rescue Exception => e
  end
end

class NoChangesException < Exception
end

$log.info("[RESTORE OPTIONS]: #{options.to_yaml}")
begin
  org,vdc,vapp = *options[:src]
  vdc.gsub!('%',' ') # Use '%' to pass spaces from test automation script

  vappdir = "ORG/#{org}/VDC/#{vdc}/VAPP/#{vapp}"
  diff1 = "'#{options[:output]}/#{options[:tree]}/#{vappdir}'"
  diff2 = "'#{options[:output]}/RESTORE/#{vappdir}'"

  src = VCloud::Org.new(org).load("#{options[:input]}/#{options[:tree]}").vdc(vdc).vapp(vapp)

  vcd = VCloud::VCD.new()
  vdc = vcd.connect(*options[:vcd]).org(org).vdc(vdc)

  vdc.vapp(vapp).saveparam("#{options[:output]}/RESTORE")
  ds = %x(diff -cbr #{diff1} #{diff2})
  $log.info("[DIFF BEFORE RESTORE]: >>#{ds}<<")
  unless (options[:skip])
    print "Continue (yN)? "; a = gets
    raise NoChangesException.new unless (a =~ /[yY]/)
  end

  vcd.wait(vdc.vapp(vapp).powerOff)
  vcd.wait(vdc.vapp(vapp).undeploy)

  vdc.vapp(vapp).restore(src)
  vdc.vapp(vapp).saveparam("#{options[:output]}/RESTORE")
  ds = %x(diff -cbr #{diff1} #{diff2})
  if (ds.size > 0)
    $log.warn("[DIFF AFTER RESTORE]: >>#{ds}<<")
  else
    $log.info("[NO DIFFs AFTER RESTORE]")
  end

rescue NoChangesException => e
  $log.info("vcd-restore operation aborted: No changes to restore.")
rescue Exception => e
  $log.error("vcd-restore failed: #{e}")
  $log.error(e.backtrace)
ensure
  exit($log.errors + $log.warns)
end

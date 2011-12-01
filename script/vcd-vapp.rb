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
$: << File.dirname(__FILE__) + "/lib"
require 'optparse'
require 'vcdkit'

options = {
  # XXX: put default options
}

$log = VCloud::Logger.new
$mail = VCloud::Mailer.new

optparse = OptionParser.new do |opt|
  opt.banner = "Usage: vcd-vapp.rb [cmd-options]"
  
  vcdopts(options,opt)

  opt.on('-A','--add','Add new vApp') do |o|
    options[:op] = :add
  end
  opt.on('-D','--delete','Delete vApp') do |o|
    options[:op] = :del
  end

  opt.on('','--vapptemplate ORG,VDC,VAPP',Array,'Specify target vAppTemplate') do |o|
    options[:vat] = o
  end
  opt.on('','--vdc ORG,VDC',Array,'Specify target vdc') do |o|
    options[:vdc] = o
  end
  opt.on('-n','--vappname NAME','Specify vapp basename') do |o|
    options[:name] = o
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
  vcd = VCloud::VCD.new()
  vcd.connect(*options[:vcd])

  case options[:op]
  when :add
    t = options[:vat]
    vdc = vcd.org(t[0]).vdc(t[1])
    vat = vdc.vapptemplate(t[2])
    vappname = Time.now.strftime("#{options[:name]}-%Y/%m/%d-%H:%M:%S")
    vcd.wait(vdc.deployVApp(vat,vappname))
  when :del
    t = options[:vdc]
    vdc = vcd.org(t[0]).vdc(t[1])
    vdc.each_vapp do |vapp|
      name = vapp.name
      if name =~ /#{options[:name]}-[\d\/]+-[\d:]+/
        $log.info("Start deleting vapp: '#{name}'")
        vcd.wait(vapp.powerOff)
        vcd.wait(vapp.undeploy)
        vdc.vapp(name).delete
      end
    end
  end

rescue Exception => e
  $log.error("vcd-vapp failed: #{e}")
  $log.error(e.backtrace)
ensure
  if($log.errors>0 && $log.temp)
    vcdhost = options[:vcd][0]
    hostname = `hostname`.chomp
    now = Time.now
    $mail.send({'vcd-vapp.log.gz' => File.read($log.compressed_temp)},
               binding)
  end
end
exit($log.errors + $log.warns)


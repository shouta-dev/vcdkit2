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
  :input => "#{$VCDKIT}/data/vcd-dump",
  :output => "#{$VCDKIT}/data/vcd-report",
  :target => :all,
}

$log = VCloud::Logger.new

optparse = OptionParser.new do |opt|
  opt.banner = "Usage: vcd-report.rb [cmd-options]"
  
  vcdopts(options,opt)

  opt.on('-i','--input DIR','Specify root directory of the vCD dump data') do |o|
    options[:input] = o
  end
  opt.on('-o','--output DIR','Specify directory for reports') do |o|
    options[:output] = o
  end

  opt.on('-a','--vapp ORG,VDC,VAPP',Array,'Create report for vApp') do |o|
    options[:targettype] = :VAPP
    options[:target] = o
  end
  opt.on('-T','--vapptemplate ORG,VDC,VAPPTEMPLATE',Array,'Create report for vApp Template') do |o|
    options[:targettype] = :VAPPTEMPLATE
    options[:target] = o
  end
  opt.on('-A','--all','Create report for entire dump tree') do |o|
    options[:target] = :all
  end

  opt.on('-t','--tree TREENAME',Array,'Directory name to identify dump tree') do |o|
    options[:tree] = o
  end

  opt.on('-f','--force','Force to recreate reports to exisiting tree') do |o|
    options[:force] = true
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

ot = options[:target]

if(options[:vcd])

  vcd = VCloud::VCD.new
  vcd.connect(*options[:vcd])

  if(ot == :all)
    vcd.saveparam("#{options[:output]}/#{options[:tree]}")
  elsif(ot.size == 3)
    case options[:targettype]
    when :VAPPTEMPLATE
      vcd.org(ot[0]).vdc(ot[1]).vapptemplate(ot[2]).saveparam("#{options[:output]}/#{options[:tree]}")
    else
      vcd.org(ot[0]).vdc(ot[1]).vapp(ot[2]).saveparam("#{options[:output]}/#{options[:tree]}")
    end
  else
    $log.error("vcd-report invalid command options")
  end

else # Load dump tree from directory

  subdir = options[:tree] || "*"
  Dir.glob("#{options[:input]}/#{subdir}").each do |d|
    next unless File.directory?(d)
    outdir = "#{options[:output]}/#{File.basename(d)}"
    next if (File.exists?(outdir) && !options[:force])

    $log.info("Start processing directory '#{d}'")
    begin
      vcd = VCloud::VCD.new
      if(ot == :all)
        vcd.load(d).saveparam(outdir)

        vc = VSphere::VCenter.new
        vc.load(d)

        FileUtils.mkdir_p(outdir)
        open("#{outdir}/MediaList.xml",'w') do |f|
          f.puts ERB.new(File.new("template/vcd-report/MediaList_Excel.erb").
                         read,0,'>').result(binding)
        end
        open("#{outdir}/VMList.xml",'w') do |f|
          f.puts ERB.new(File.new("template/vcd-report/VMList_Excel.erb").
                         read,0,'>').result(binding)
        end

      elsif(ot.size == 3)
        org = VCloud::Org.new(ot[0]).load(d)
        vdc = VCloud::Vdc.new(org,ot[1]).load(d)
        
        case options[:targettype]
        when :VAPPTEMPLATE
          vdc.vapptemplate(ot[2]).load(d).saveparam(outdir)
        else
          vdc.vapp(ot[2]).load(d).saveparam(outdir)
        end

      elsif(ot.size == 1)
        VCloud::Org.new(ot[0]).load(d).saveparam(outdir)
      end

    rescue Exception => e
      $log.error("vcd-report failed: #{e}")
      $log.error(e.backtrace)
    end
  end
end
exit($log.errors + $log.warns)

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
require 'date'
require 'vcdkit'

options = {
  :input => "#{$VCDKIT}/data/vcd-report",
  :output => "#{$VCDKIT}/data/vcd-trend",
  :target => :all,
  :offset => 1,
}

$log = VCloud::Logger.new
$mail = VCloud::Mailer.new

optparse = OptionParser.new do |opt|
  opt.banner = "Usage: vcd-trend.rb [cmd-options]"
  
  vcdopts(options,opt)

  opt.on('-i','--input DIR','Specify root directory of the report data') do |o|
    options[:input] = o
  end
  opt.on('-o','--output DIR','Specify directory for trend data') do |o|
    options[:output] = o
  end

  opt.on('','--offset OFFSET','Offset of starting month(default=1)') do |o|
    options[:offset] = o
  end

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

# Determine target report data range
pm = (Date.parse(Time.now.to_s) << options[:offset].to_i) # previous month
first = Date.civil(pm.year,pm.month,1) 
last = Date.civil(pm.year,pm.month,-1)

repdirs = Dir.glob("#{options[:input]}/*-*-*_*-*-*").select do |d| 
  if (File.directory?(d))
    d =~ /\/(\d{4})-(\d{2})-(\d{2})/
    dt = Date.civil($1.to_i,$2.to_i,$3.to_i)
    first <= dt && dt <= last
  else
    false
  end
end.sort

outdir = "#{options[:output]}/#{File.basename(repdirs.first)}__#{File.basename(repdirs.last)}"
FileUtils.mkdir_p(outdir) unless File.exists? outdir

data = {}
summary = {}
repdirs.each do |d|
  next unless File.exists?("#{d}/VMList.xml")
  doc = REXML::Document.new(File.new("#{d}/VMList.xml").read)
  tree = File.basename(d)
  $log.info("Start processing '#{tree}'")
  r = -1
  doc.elements.each('//Row') do |row|
    r += 1
    next if r == 0

    c = 0
    rd = []
    row.elements.each('./Cell') do |cell|
      rd[c] = cell.elements['./Data'].text
      c += 1
    end
    next if rd[6].nil?

    # org
    data[rd[1]] = {} if (data[rd[1]].nil?)
    summary[rd[1]] = {} if (summary[rd[1]].nil?)
    
    # vdc
    data[rd[1]][rd[2]] = {} if (data[rd[1]][rd[2]].nil?)

    # os
    data[rd[1]][rd[2]][rd[6]] = {} if (data[rd[1]][rd[2]][rd[6]].nil?)
    ostype = case rd[6]
          when /^Microsoft Windows Server/
            'Windows Server'
          when /Microsoft Windows/
            'Other Windows'
          else
            'Other OS'
          end
    summary[rd[1]][ostype] = {} if (summary[rd[1]][ostype].nil?)

    # tree
    data[rd[1]][rd[2]][rd[6]][tree] = 0 if (data[rd[1]][rd[2]][rd[6]][tree].nil?)
    data[rd[1]][rd[2]][rd[6]][tree] += 1

    summary[rd[1]][ostype][tree] = 0 if (summary[rd[1]][ostype][tree].nil?)
    summary[rd[1]][ostype][tree] += 1
  end
end

$log.info("Saving GuestList.xml...")
open("#{outdir}/GuestList.xml",'w') do |f|
  f.puts ERB.new(File.new("template/vcd-trend/GuestList_Excel.erb").
                 read,0,'>').result(binding)
end

$log.info("Saving GuestSummary.xml...")
open("#{outdir}/GuestSummary.xml",'w') do |f|
  f.puts ERB.new(File.new("template/vcd-trend/GuestSummary_Excel.erb").
                 read,0,'>').result(binding)
end

# following local variables can be accessable from inside
# mailer conf templates via binding
vcdhost = options[:vcd][0]
hostname = `hostname`.chomp
now = Time.now
$mail.send({"GuestList.xml" =>
             File.read("#{outdir}/GuestList.xml"),
             "GuestSummary.xml" =>
             File.read("#{outdir}/GuestSummary.xml")
           },binding)

exit($log.errors + $log.warns)

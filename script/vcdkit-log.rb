#!/usr/bin/ruby
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

data={}

ARGV.each do |file|
  data[file] ||= {
    'INFO' => [],
    'WARN' => [],
    'ERROR' => [],
  }
  f = File.new(file)
  while(line = f.gets)
    next unless (line =~ /^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\s*\|\s*(\S+)\s*\|/)==0
    data[file][$2] << $1
  end
end


FORMAT="%-24s %-24s %-24s"
puts sprintf(FORMAT,'FILE','LAST INFO','LAST ERROR')
data.keys.sort.each do |file|
  d = data[file]
  puts sprintf(FORMAT,file,d['INFO'].last,d['ERROR'].last)
end


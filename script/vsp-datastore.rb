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
}

$log = VCloud::Logger.new
$mail = VCloud::Mailer.new

optparse = OptionParser.new do |opt|
  opt.banner = "Usage: vcd-datastore.rb [options]"

  opt.on('-C','--conf CONFFILE','Configuration file name') do |o|
    options[:conf] = o
  end

  opt.on('-D','--dir','Perform directory creation and deletion') do |o|
    options[:dir] = true
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

$esxpass = VCloud::SecurePass.new().decrypt(File.new('.esx','r').read)
$ERROR = {}

def each_datastore(fm,ds,options)
  dspath = "[#{ds.name}] __VCDKIT_TMPDIR__"
  if(options[:conf])
    $log.info("Test datastore access: Datastore '#{ds.name}'")
  else
    puts "  <datastore>#{ds.name}</datastore>"
  end
  begin
    # ensure no left-overs from the last run
    if(options[:dir])
      fm.DeleteDatastoreFile_Task('name' => dspath).wait_for_completion
    end
  rescue Exception => e
  end
  if(options[:dir])
    fm.MakeDirectory('name' => dspath)
    fm.DeleteDatastoreFile_Task('name' => dspath).wait_for_completion
  end
end

def each_esx(hostname,datastores,options)
  esx = VSphere::VCenter.new
  esx.connect(hostname,'root',$esxpass)

  fm = esx.scon.fileManager
  if(options[:conf])
    $log.info("Test datastore access: ESX '#{hostname}'")
  else
    puts "  <esx>#{hostname}</esx>"
  end
  esx.root.childEntity.grep(RbVmomi::VIM::Datacenter).each do |dc|
    if (datastores.nil?)
      dc.datastore.each do |ds|
        each_datastore(fm,ds,options)
      end
    else
      datastores.each do |dsname|
        ds = dc.find_datastore(dsname)
        $ERROR[:host] = hostname
        $ERROR[:datastore] = dsname
        if(ds.nil?)
          raise "Datastore '#{dsname}' cannot be found"
        else
          each_datastore(fm,ds,options)
        end
        $ERROR = {}
      end
    end
  end
end

begin
  if(options[:conf])
    conf = REXML::Document.new(File.new(options[:conf],'r').read)
    ds = conf.elements.collect('//dslist/datastore') {|n| n.text}
    conf.elements.each('//dslist/esx') do |h|
      each_esx(h.text,ds,options)
    end
  else
    vc = VSphere::VCenter.new
    vc.connect(*options[:vsp])
    puts <<EOS
<?xml version="1.0" encoding="UTF-8"?>
<dslist>
EOS
    vc.root.childEntity.grep(RbVmomi::VIM::Datacenter).each do |dc|
      dc.hostFolder.childEntity.grep(RbVmomi::VIM::ComputeResource).each do |c|
        c.host.each do |h|
          each_esx(h.name,nil,options)
        end
      end
    end
puts <<EOS
</dslist>
EOS
  end
rescue Exception => e
  $log.error("vsp-datastore failed: #{e}")
  $log.error(e.backtrace)
  exit 1
ensure
  if($log.errors>0 && $log.temp)
    # following local variables can be accessable from inside
    # mailer conf templates via binding
    vcdhost = options[:vcd][0]
    hostname = `hostname`.chomp
    now = Time.now
    error_host = $ERROR[:host] || ''
    error_datastore = $ERROR[:datastore] || ''
    $mail.send({'vsp-datastore.log.gz' => File.read($log.compressed_temp)},
               binding)
  end
end

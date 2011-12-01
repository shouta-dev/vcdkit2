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
require 'vcb'

options={
  :threshold => 5400,
}

$log = VCloud::Logger.new
$mail = VCloud::Mailer.new

optparse = OptionParser.new do |opt|
  opt.banner = "Usage: vcb-ex.rb [options]"

  vcopts(options,opt)
  vcbdbopts(options,opt)

  VCloud::Logger.parseopts(opt)
  VCloud::Mailer.parseopts(opt)

  opt.on('','--threshold SECS','Threshold for dc thread timestamp') do |n|
    options[:threshold] = n
  end

  opt.on('','--vcddc DCVMS',Array,'Specify vCD data-collector VMs') do |o|
    options[:vcddc] = o
  end
  opt.on('','--restart_vcddc','Enforce to restart vCD data-collector service') do |o|
    options[:restart_vcddc] = true
  end

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

def find_esx(opts, vmname)
  vc = VSphere::VCenter.new
  vc.connect(opts[:vsp][0],opts[:vsp][1],File.new('.esx','r'))

  vc.root.childEntity.grep(RbVmomi::VIM::Datacenter).each do |dc|
    dc.hostFolder.childEntity.grep(RbVmomi::VIM::ComputeResource).each do |c|
      c.host.each do |h|
        h.vm.each do |vm|
          if vm.name == vmname
            return h.name
          end
        end
      end
    end
  end
  ret
end

def restart_vcddc(opts)
  script = 'C:\\\\PROGRA~2\\\\VMware\\\\VMWARE~1\\\\VMWARE~1\\\\restart-vcddc.bat'
  esxpass = VCloud::SecurePass.new().decrypt(File.new('.esx','r').read)

  (opts[:vcddc] || []).each do |cbvm|
    esx = find_esx(opts,cbvm)
    cmd = "./vix-run.pl -h #{esx} -v #{cbvm} -p #{esxpass} -s #{script} -l logs/vix-run.log"
    $log.info("Executing command #{cmd.sub(esxpass,'****')}")
    if system(cmd)
      $log.info("Service restarted successfully")
    else
      $log.error("Failed to restart service: #{$?}")
    end
    unless cbvm == opts[:vcddc].last
      $log.info("Wait 3 mins before restarting another data-collector")
      verbose_sleep(180)
    end
  end
end

def verbose_sleep(s)
  while s > 0
    sleep 2; s -= 2
    print '.'
    print "#{s}" if (s % 10 == 0)
    STDOUT.flush
  end
  print "¥n"
end

TIMEFORMAT = '%Y-%m-%d %H:%M:%S'

begin
  vcbdb = Chargeback::VCBDB.new
  conn = vcbdb.connect(*options[:vcbdb])
  if conn.nil?
    $log.info("Failed to connect database. Skip the rest of tests.")
    exit(0)
  end

  now = Time.now
  ts_fc = vcbdb.lastFixedCost
  diff = now - ts_fc
  tstr = ts_fc.strftime(TIMEFORMAT)
  fcerror = false
  if(diff > options[:threshold])
    $log.error("Last Fixed Cost #{tstr}(#{diff.to_i} secs old)")
    fcerror = true
  else
    $log.info("Last Fixed Cost #{tstr}(#{diff.to_i} secs old)")
  end

  vcbdb.dcThreads.each do |th|
    ts = th.lastProcessTime
    diff = now - ts
    tstr = ts.strftime(TIMEFORMAT)
    if(diff > options[:threshold] && fcerror)
      $log.error("Last Process Time #{tstr}(#{diff.to_i} secs old): #{th.name}")
    else
      $log.info("Last Process Time #{tstr}(#{diff.to_i} secs old): #{th.name}")
    end
  end

  Chargeback::VCBDB::VM.searchByStartTime(conn,{:t0 => ts_fc,:t1 => Time.now}) do |vm|
    c = vm.created.strftime('%Y-%m-%d %H:%M:%S')
    d = vm.deleted.strftime('%Y-%m-%d %H:%M:%S')
    $log.info("Unprocessed VM: #{vm.org}/#{vm.vdc}/#{vm.vapp}/#{vm.name}(#{vm.heid}) #{c}~#{d}")
  end

  if($log.errors > 0)
    # On error, restart vCD data collector
    options[:restart_vcddc] = true
  end

  if options[:restart_vcddc]
    restart_vcddc(options)
  end

rescue SystemExit => e
  exit(e.status)
rescue Exception => e
  $log.error("vcb-ex failed: #{e}")
  $log.error(e.backtrace)

ensure
  if($log.errors>0 && $log.temp)
    # following local variables can be accessable from inside
    # mailer conf templates via binding
    vcbdb = options[:vcbdb][0]
    hostname = `hostname`.chomp
    now = Time.now
    $mail.send({'vcb-ex.log' => File.read($log.temp.path)},
               binding)
  end
end
exit ($log.errors + $log.warns)

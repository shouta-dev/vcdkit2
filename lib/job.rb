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
require 'rubygems'
require 'rufus/scheduler'
require 'vcdkit'

module VCloudJob
  class JobData
    include DataMapper::Resource
    property :id, Serial
    property :job, String
    property :started_at, DateTime
    property :finished_at, DateTime

    def duration
      return '' if (finished_at.nil? || started_at.nil?)
      days = finished_at - started_at
      hrs = (days - days.floor) * 24
      mins = (hrs - hrs.floor) * 60
      secs = (mins - mins.floor) * 60
      sprintf("%02d hr %02d min %02d sec",
              hrs.floor,mins.floor,secs.floor)
    end
  end

  class JobBase
    attr_reader :id, :log
    def initialize
      jd = JobData.new(:job => self.class.name.sub('VCloudJob::',''),
                       :started_at => Time.now)
      jd.save
      @log = VCloud::DataMapperLogger.new(jd.id)
      @id = jd.id
    end

    def finish
      JobData.get(@id).update(:finished_at => Time.now)
    end

    def run
      begin
        self.execute
      rescue Exception => e
        log.error("#{self.class.name} failed: #{e}")
        e.backtrace.each do |l|
          log.backtrace(l)
        end
      ensure
        self.finish
      end
    end
  end

  class VCDDump < JobBase
    def execute
      dumper = VCloud::Dumper.new(self)
      vcd = VCloud::VCD.new(self.log)
      vcd.connect(*(VCloud::VCD.connectParams)).save(dumper)
      vc = VSphere::VCenter.new(self.log)
      vc.connect(*(VSphere::VCenter.connectParams)).save(dumper)
    end
  end

  class VCDEX < JobBase
    def run
      vcd = VCloud::VCD.new(self.log)
      vcd.connect(*(VCloud::VCD.connectParams))
    end
  end

  class Schedule
    include DataMapper::Resource
    property :id, Serial
    property :job, String
    property :schedule, String
  end

  class Scheduler
    def initialize
      @sched = Rufus::Scheduler.start_new
      @log = VCloud::DataMapperLogger::systemLog

      Schedule.all.each do |s|
        _s = s.schedule.split(/\s+/)
        eval <<EOS
@sched.#{_s[0]} '#{_s[1]}' do
  #{s.job}.new.run
end
EOS
      end
    end
  end
end

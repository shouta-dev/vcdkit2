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
require 'tempfile'
require 'pony'
require 'data_mapper'

class DateTime
  def to_s
    self.strftime('%Y-%m-%d %H:%M:%S')
  end
end
class Time
  def to_s
    self.strftime('%Y-%m-%d %H:%M:%S')
  end
end

module VCloud
  class Logger
    attr_reader :temp,:errors,:warns

    def Logger.parseopts(opt)
      opt.on('-l','--logfile LOGFILEPATH','Log file name') do |path|
        dir = File.dirname(path)
        FileUtils.mkdir_p(dir) unless File.exists? dir
        $log.add_logger(::Logger.new(path,10,20480000))
        # keep last 10 generations, cap size at 20MB
      end
      opt.on('-t','--tempfile','Output log to temporary file') do |o|
        $log.add_logger(Tempfile.new(self.name))
      end

    end

    def initialize
      @loggers = []
      @warns = @errors = 0
      self.add_logger(::Logger.new(STDOUT))
    end

    def add_logger(l)
      if(l.class == Tempfile)
        @temp = l
        l = ::Logger.new(@temp.path)
      end

      l.formatter = proc {|sev,time,prog,msg|
        "#{time} | #{sev} | #{msg}\n"
      }
      @loggers.push(l)
    end

    def info(msg)
      @loggers.each {|l| l.info(msg)}
    end
    def error(msg)
      @errors += 1
      @loggers.each {|l| l.error(msg)}
    end
    def warn(msg)
      @warns += 1
      @loggers.each {|l| l.warn(msg)}
    end

    def compressed_temp
      @ctemp = Tempfile.new(self.class.name)
      Zlib::GzipWriter.open(@ctemp.path) do |gz|
        gz.write @temp.read 
      end
      @ctemp.path
    end
  end

  class Log
    include DataMapper::Resource
    property :id, Serial
    property :jobid, Integer
    property :created_at, DateTime
    property :priority, String
    property :message, Text
  end

  class DataMapperLogger
    def DataMapperLogger.systemLog
      DataMapperLogger.new(-1)
    end

    def initialize(jobid)
      @jobid = jobid
    end
    def mklog(pri,msg)
      Log.create(:jobid => @jobid,
                 :created_at => Time.now,
                 :priority => pri,
                 :message => msg)
    end

    def warn(msg)
      mklog('WARN',msg)
    end
    def info(msg)
      mklog('INFO',msg)
    end
    def error(msg)
      mklog('ERROR',msg)
    end
    def backtracek(msg)
      mklog('BACKTRACE',msg)
    end
  end

  class Dumper
    attr_reader :tree
    def initialize(job)
      @tree = DumpTree.new(:created_at => Time.now,
                           :jobid => job.id)
      @tree.save
      @log = job.log
    end

    def save(obj)
      begin
        @log.info("SAVE: ##{@tree.id}: #{obj.type} | #{obj.path}")
        DumpData.create(:treeid => @tree.id,
                        :created_at => Time.now,
                        :type => obj.class.name,
                        :name => obj.name,
                        :path => obj.path,
                        :xml => obj.xml)
      rescue DataMapper::SaveFailureError => e
        @log.error("SAVE FAILURE: ##{@tree.id}: #{obj.type} | #{obj.path}")
      end
    end
  end

  class Mailer
    attr_reader :conf
    def Mailer.parseopts(opt)
      opt.on('-m','--mailconf CONFFILE','Mailer configuration file name') do |c|
        $mail.configure(c)
      end
    end

    def configure(conf)
      @conf = REXML::Document.new(File.new(conf))
    end

    def Mailer.build(template,bind)
      ERB.new(template.gsub('{%','<%').gsub('%}','%>')).result(bind)
    end

    def send(attachments,bind)
      if(@conf.nil?) 
        $log.info("Mailer configuration is not specified. Skip sending email")
        return
      end
      e = @conf.elements['/mailerconf'].elements

      smtp_opts = {
        :address => e['./smtp/host'].text,
        :domain => "localhost.localdomain",
      }
      port = e['./smtp/port']
      user = e['./smtp/user']
      pass = e['./smtp/password']
      auth = e['./smtp/authentication']

      smtp_opts.update(:port => port.text) if port
      smtp_opts.update(:user_name => user.text) if user
      smtp_opts.update(:password => pass.text) if pass
      smtp_opts.update(:authentication => auth.text) if auth

      Pony.mail(:to => e.collect('./to') {|to| to.text}.join(','),
                :from => Mailer.build(e['./from'].text,bind),

                :subject => Mailer.build(e['./subject'].text,bind),
                :body => Mailer.build(e['./body'].text,bind),
                :attachments => attachments,

                :via => :smtp,
                :via_options => smtp_opts
                )
    end
  end
end


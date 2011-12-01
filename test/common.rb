require 'rexml/document'
require 'rake/clean'

VCDKIT=ENV['VCDKIT']
LOG="#{VCDKIT}/logs/test.log"

CLEAN.include(LOG,'**/*.done')
# Verbose shell command execution
verbose(true)

CONF = REXML::Document.new(File.new("#{VCDKIT}/conf/test.xml"))

class Target
  attr_reader :name,:command,:done
  attr_accessor :repeat
  @@id = 0

  def initialize(name,params={})
    @name = name
    @done = "#{name}#{@@id}.done"
    @repeat = params[:repeat] || 1
    opts = (params[:opts] || []).collect {|o| 
      if (o.class == Symbol)
        e = CONF.root.elements["//cmdopt[@name='#{o}']"]
        if(e.nil?)
          raise "Cannot find command option: '#{o}'"
        end
        e.text
      else
        o
      end
    }
    @command = "#{VCDKIT}/#{name}.rb #{opts.join(' ')}"
    @@id += 1
  end

  def setup
    cmds = ([command] * @repeat).join(' && ')
    file @done do |task|
      sh "#{cmds} && touch #{@done}"
    end
  end

  def Target.setup(*targets)
    task :default => targets.collect{|t| t.done}
    targets.each {|t| t.setup}
  end
end

class DirTarget < Target
  def initialize(name,params={})
    super
    @command = "rake"
  end

  def setup
    file self.done do |task|
      sh "pushd #{name} && #{command} && popd && touch #{done}"
    end
  end
end



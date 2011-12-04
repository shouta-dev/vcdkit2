require 'rexml/document'
require 'rake/clean'
include Rake::DSL

VCDKIT=ENV['VCDKIT']

CLEAN.include('**/*.done',"#{VCDKIT}/data/*")
# Verbose shell command execution
verbose(true)

class Target
  include Rake::DSL
  attr_reader :name,:command,:done
  @@id = 0

  def initialize(name,opts=[])
    @name = name.sub(/\.rb$/,'')
    @done = "#{@name}_#{@@id}.done"
    @command = "#{name} #{opts.join(' ')}"
    @@id += 1

    file @done do |task|
      sh "#{@command} && touch #{@done}"
    end
  end
end

targets = YAML::load(File.new('./config.yml').read).collect do |t|
  script = t.shift
  Target.new(script,t)
end
task :default => targets.collect{|t| t.done}


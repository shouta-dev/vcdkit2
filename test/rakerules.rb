require 'rexml/document'
require 'rake/clean'
include Rake::DSL

VCDKIT=ENV['VCDKIT']

CLEAN.include('**/*.done')
# Verbose shell command execution
verbose(true)

class Target
  include Rake::DSL
  attr_reader :name,:command,:done
  @@id = 0

  def initialize(name,opts=[])
    @name = name
    @done = "#{name}#{@@id}.done"
    @command = "#{VCDKIT}/script/#{name}.rb #{opts.join(' ')}"
    @@id += 1

    file @done do |task|
      sh "#{@command} && touch #{@done}"
    end
  end

  def Target.setup(*targets)
    task :default => targets.collect{|t| t.done}
  end
end

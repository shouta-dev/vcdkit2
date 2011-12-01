require '../common'

Target.setup(Target.new('vcd-dump',:opts => [:vcd,:vc,:tree,:org,:log]),
             Target.new('vcd-report',:opts => [:vapp,:log]),
             Target.new('vcd-restore',:opts => ['-s',:vcd,:tree,:vapp,:log]))

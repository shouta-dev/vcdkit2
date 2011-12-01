require '../common'

Target.setup(Target.new('vcd-vapp',:opts => [:vcd,:vapp_del]),
             Target.new('vcd-vapp',:opts => [:vcd,:vapp_add]))

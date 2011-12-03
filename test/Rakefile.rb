require 'rakerules'

LOG='/tmp/vcdkittest.log'

Target.setup(Target.new('vcd-dump',["--log /tmp/#{LOG}",'--tree VCDKITTEST']),
             Target.new('vcd-report',["--log /tmp/#{LOG}",'--tree VCDKITTEST']))




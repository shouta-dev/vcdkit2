# vcd-test.rb
# vcd-vapp.rb
# vcd-vm.rb

require 'common'

Target.setup(Target.new('vcd-ex',:opts => [:vcd,:exops]),
             DirTarget.new('restore'),
             DirTarget.new('trend')
             )


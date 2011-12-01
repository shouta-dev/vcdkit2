######################################################################################
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
require 'rexml/document'
require 'erb'
require 'vclouddata'
require 'pp'

module VCloud

  VAPPSTATUS = {
    "4" => "Powered On",
    "8" => "Powered Off",
  }

  class Vm < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.vm+xml'

    def os
      @doc.elements["//ovf:OperatingSystemSection/ovf:Description/text()"].to_s
    end
    def osType
      @doc.elements["//ovf:OperatingSystemSection/@vmw:osType"].value
    end

    def status
      VAPPSTATUS[@doc.elements["/Vm/@status"].value] || "Busy"
    end

    def thumbnail
      @vcd.get(@doc.elements["//Link[@rel='screen:thumbnail']/@href"].value).body
    end

    def moref
      @doc.elements["//vmext:VmVimObjectRef/vmext:MoRef/text()"].to_s
    end
    
    def powerOff
      Task.new.post(@vcd,@doc.elements["//Link[@rel='power:powerOff']"])
    end

    def editNetworkConnectionSection(ntwkcon)
      Task.new.put(@vcd,
                   @doc.elements["//NetworkConnectionSection/Link[@rel='edit']"],
                   NetworkConnectionSection.new(self,ntwkcon).xml(true),
                   {:content_type => NetworkConnectionSection::TYPE})
    end

    def editGuestCustomizationSection(node)
      Task.new.put(@vcd,
                   @doc.elements["//GuestCustomizationSection/Link[@rel='edit']"],
                   GuestCustomizationSection.new(self,node).xml(true),
                   {:content_type => GuestCustomizationSection::TYPE})
    end

    def editOperatingSystemSection(node)
      Task.new.put(@vcd,
                   # Can't locate Link node if @rel='edit' is specified... 
                   @doc.elements["//ovf:OperatingSystemSection/Link"],
                   OperatingSystemSection.new(self,node).xml(true),
                   {:content_type => OperatingSystemSection::TYPE})
    end

    def connectNetwork(nic,name,mode)
      ncon = @doc.elements["//NetworkConnection[NetworkConnectionIndex ='#{nic}']"]
      ncon.attributes['network'] = name
      ncon.elements["//IsConnected"].text = 'true'
      ncon.elements["//IpAddressAllocationMode"].text = mode
      cfg = ncon.elements["../"]

      Task.new.put(@vcd,
                   cfg.elements["//Link[@type='#{NetworkConnectionSection::TYPE}']"],
                   self.compose_xml(cfg),
                   :content_type => NetworkConnectionSection::TYPE)
    end

    def disconnectNetworks()
      self.editNetworkConnectionSection(nil)
    end

    def customize(args)
      cfg = @doc.elements["//GuestCustomizationSection"]
      GuestCustomizationSection.compose(cfg,args)

      Task.new.put(@vcd,
                   cfg.elements["//Link[@type='#{GuestCustomizationSection::TYPE}']"],
                   self.compose_xml(cfg),
                   :content_type => GuestCustomizationSection::TYPE)
    end

    def edit(src)
      Task.new.put(@vcd,
                   self.elements["//Link[@type='#{EditVmParams::TYPE}' and @rel='edit']"],
                   EditVmParams.new(self,src).xml,
                   {:content_type => EditVmParams::TYPE})
      
    end

    def initialize(parent,name)
      @parent = parent; @name = name
    end

    def path
      "#{@parent.path}/VM/#{@name}"
    end
  end

  class VmTemplate < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.vm+xml'
    def initialize(parent,name)
      @parent = parent; @name = name
    end

    def moref
      @doc.elements["//VCloudExtension/vmext:VimObjectRef/vmext:MoRef/text()"]
    end
    
    def path
      "#{@parent.path}/VMTEMPLATE/#{@name}"
    end
  end

  class VAppTemplate < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.vAppTemplate+xml'

    def initialize(org,vdc,name)
      @org = org; @vdc = vdc; @name = name
    end
      
    def path
      "#{@vdc.path}/VAPPTEMPLATE/#{@name}"
    end

    def vm(name)
      vm = VmTemplate.new(self,name)
      if(@vcd)
        vm.connect(@vcd,@doc.elements["//Children/Vm[@name='#{name}']"])
      elsif(@dir)
        vm.load(@dir)
      end
    end

    def each_vm
      @doc.elements.each("//Children/Vm"){|n| 
        vm = VmTemplate.new(self,n.attributes['name'].to_s)
        if(@vcd)
          vm.connect(@vcd,n)
        elsif(@dir)
          vm.load(@dir)
        end
        yield vm
      }
    end

    def save(dir)
      super
      self.each_vm {|vm| vm.save(dir)}
    end

    def saveparam(dir)
      super
      self.each_vm {|vm| vm.saveparam(dir)}
    end

    def delete
      @vcd.delete(@doc.elements["//Link[@rel='remove']/@href"].value)
    end
  end

  class ControlAccessParams < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.controlAccess+xml'

    def initialize(vapp,name)
      @vapp = vapp
    end
      
    def path
      @vapp.path
    end
  end

  class VApp < VAppTemplate
    TYPE = 'application/vnd.vmware.vcloud.vApp+xml'
    attr_reader :org

    def initialize(org,vdc,name)
      @org = org; @vdc = vdc; @name = name
    end
      
    def owner
      n = self['/VApp/Owner/User/@name']
      if (n.nil?)
        ''
      else
        n.value
      end
    end

    def path
      "#{@vdc.path}/VAPP/#{@name}"
    end

    def vm(name)
      vm = Vm.new(self,name)
      if(@vcd)
        vm.connect(@vcd,@doc.elements["//Children/Vm[@name='#{name}']"])
      elsif(@dir)
        vm.load(@dir)
      end
    end

    def each_vm
      @doc.elements.each("//Children/Vm"){|n| 
        vm = Vm.new(self,n.attributes['name'].to_s)
        if(@vcd)
          vm.connect(@vcd,n)
        elsif(@dir)
          vm.load(@dir)
        end
        yield vm
      }
    end

    def save(dir)
      super
      self.cap.save(dir)
    end

    def status
      VAPPSTATUS[@doc.elements["/VApp/@status"].value] || "Busy"
    end

    def deploy()
      Task.new.post(@vcd,
                    @doc.elements["//Link[@type='#{DeployVAppParams::TYPE}']"],
                    DeployVAppParams.new().xml,
                    {:content_type => DeployVAppParams::TYPE})
    end

    def editNetworkConfigSection(node)
      Task.new.put(@vcd,
                   @doc.elements["//NetworkConfigSection/Link[@rel='edit']"],
                   NetworkConfigSection.new(self,node).xml(true),
                   {:content_type => NetworkConfigSection::TYPE})
    end

    def editLeaseSettingsSection(node)
      Task.new.put(@vcd,
                   @doc.elements["//LeaseSettingsSection/Link[@rel='edit']"],
                   LeaseSettingsSection.new(self,node).xml(true),
                   {:content_type => LeaseSettingsSection::TYPE})
    end

    def editStartupSection(e)
      Task.new.put(@vcd,
                   # Adding @rel='edit' breaks the xpath search. Why??
                   @doc.elements["//ovf:StartupSection/Link"],
                   self.compose_xml(e),
                   {:content_type => StartupSection::TYPE})
    end

    def editControlAccessParams(e)
      Task.new.post(@vcd,
                    @doc.elements["/VApp/Link[@rel='controlAccess']"],
                    self.compose_xml(e),
                    {:content_type => ControlAccessParams::TYPE})
    end

    def editOwner(e)
      if(e.nil?)
        # 1.0API payload. Just ignore
        Task.new
      else
        Task.new.put(@vcd,
                     @doc.elements["/VApp/Link[@type='#{Owner::TYPE}']"],
                     self.compose_xml(e),
                     {:content_type => Owner::TYPE})
      end
    end

    def restore(src)
      @vcd.wait(self.editControlAccessParams(src.cap.doc.root))
      @vcd.wait(self.editOwner(src['/VApp/Owner']))
      @vcd.wait(self.editStartupSection(src['//ovf:StartupSection']))
      @vcd.wait(self.editLeaseSettingsSection(src))
      @vcd.wait(self.edit(src))

      self.each_vm do |vm|
        srcvm = src.vm(vm.name)
        @vcd.wait(vm.edit(srcvm))
        @vcd.wait(vm.editGuestCustomizationSection(srcvm))
        @vcd.wait(vm.editOperatingSystemSection(srcvm))
      end

      @vcd.wait(self.editNetworkConfigSection(src))
      self.each_vm do |vm|
        @vcd.wait(vm.editNetworkConnectionSection(src.vm(vm.name)))
      end
    end

    def edit(src)
      Task.new.put(@vcd,
                   self.elements["//Link[@type='#{EditVAppParams::TYPE}' and @rel='edit']"],
                   EditVAppParams.new(self,src).xml,
                   {:content_type => EditVAppParams::TYPE})
      
    end

    def cap()
      unless(@cap)
        @cap = ControlAccessParams.new(self,@name)
        if(@vcd)
          n = REXML::XPath.first(@doc, "/VApp/Link[@type='#{ControlAccessParams::TYPE}' and @rel='down']")
          @cap.connect(@vcd,n)
        elsif(@dir)
          @cap.load(@dir)
        end
      end
      @cap
    end

    def powerOn
      task = Task.new
      if(@doc.elements["/VApp/@status"].value != "4")
        task.post(@vcd,
                  @doc.elements["/VApp/Link[@rel='power:powerOn']"])
      end
      task
    end

    def powerOff
      task = Task.new
      if(@doc.elements["/VApp/@status"].value != "8")
        task.post(@vcd,
                  @doc.elements["/VApp/Link[@rel='power:powerOff']"])
      end
      task
    end
    
    def undeploy
      task = Task.new
      if(@doc.elements["VApp/@deployed"].value == "true")
        task.post(@vcd,
                  @doc.elements["//Link[@type='#{UndeployVAppParams::TYPE}']"],
                  UndeployVAppParams.new(self).xml,
                  {:content_type => UndeployVAppParams::TYPE})
      end
      task
    end
  end
end

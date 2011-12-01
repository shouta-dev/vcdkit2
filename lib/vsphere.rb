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
require 'rbvmomi'
require 'erb'

#
# VSphere
#
module VSphere
  class Media
    attr_reader :path,:vdc,:datastore,:org
    def load(node)
      @path = node.elements["./@path"].value
      @vdc = node.elements["./VDC/@path"].value
      @datastore = node.elements["./Datastore/@path"].value
      @org = node.elements["./Organization/@path"].value
    end
  end

  class Vm 
    attr_reader :name,:esx,:datastore,:guestFullName,:guestFamily

    def initialize
      # ensure never returns nil for attributes
      @name = @esx = @datastore = @guestFullName = @guestFamily = ''
    end

    def load(node)
      @name = node.attributes['name']
      @esx = node.elements["../@name"].value
      
      @guestFullName = node.elements["./Guest/@name"].value
      @guestFamily = node.elements["./Guest/@family"].value


      ds = node.elements["./Datastore/@name"]
      @datastore = ""
      @datastore = ds.value unless ds.nil?
    end
  end

  class DatastoreBrowser
    def initialize(ds)
      @datastore = ds
    end

    def search(path)
      spec = RbVmomi::VIM::HostDatastoreBrowserSearchSpec.new
      spec.query = [RbVmomi::VIM::FileQuery.new]
      begin 
        task = @datastore.browser.SearchDatastoreSubFolders_Task('datastorePath' => path,'searchSpec' => spec)
        task.wait_for_completion
        task.info.result
      rescue Exception => e
        []
      end
    end

    def each_media()
      self.search("[#{@datastore.info.name}] ").each do |f|
        orgpath = f.folderPath
        next unless (orgpath =~ /.*\/media\/(\d+-org)/ || # 1.0
                     orgpath =~ /.*\/media\/(org \([0-9a-f\-]+\))/)   # 1.5
        org = $1

        self.search(orgpath).each do |f|
          vdcpath = f.folderPath
          next unless (vdcpath =~ /(\d+-vdc)/ || # 1.0
                       vdcpath =~ /(vdc \([0-9a-f\-]+\))/) # 1.5
          vdc = $1

          self.search(vdcpath).each do |f|
            f.file.each {|f| yield [@datastore.info.name,org,vdc,f.path]}
          end    
        end
      end
    end
  end

  class VIMBase
    attr_reader :vc, :name
    def initialize(vc)
      @vc = vc
    end
    def xml
      ''
    end
    def save(dumper)
      @vc.log.info("SAVE: #{self.path}")
      dumper.save(self)
    end
  end

  class DataCenter < VIMBase
    def path
      "#{@vc.path}/DataCenter/#{@dc.name}"
    end
    def initialize(vc,dc)
      super(vc)
      @dc = dc
      @name = dc.name
    end
    def save(dumper)
      super
      @dc.hostFolder.childEntity.grep(RbVmomi::VIM::ComputeResource).each do |cr|
        ComputeResource.new(vc,self,cr).save(dumper)
      end
    end
  end

  class ComputeResource < VIMBase
    def path
      "#{@dc.path}/ComputeResource/#{@cr.name}"
    end
    def initialize(vc,dc,cr)
      super(vc)
      @dc = dc
      @cr = cr
      @name = cr.name
    end
    def save(dumper)
      super
      @cr.host.each do |hs|
        HostSystem.new(vc,self,hs).save(dumper)
      end
    end
  end

  class HostSystem < VIMBase
    def path
      "#{@cr.path}/HostSystem/#{@hs.name}"
    end
    def initialize(vc,cr,hs)
      super(vc)
      @cr = cr
      @hs = hs
      @name = hs.name
    end
    def save(dumper)
      super
      @hs.vm.each do |vm|
        VirtualMachine.new(vc,self,vm).save(dumper)
      end
    end
  end

  class VirtualMachine < VIMBase
    def path
      "#{@hs.path}/VirtualMachine/#{@vm.name}"
    end
    def initialize(vc,hs,vm)
      super(vc)
      @hs = hs
      @vm = vm
      @name = vm.name
    end
    def save(dumper)
      super
    end
    def xml
      ds = @vm.datastore.collect do |ds|
        "<Datastore name=\"#{ds.name}\"/>"
      end.join
      
      _xml = <<EOS
<?xml version="1.0" encoding="UTF-8"?>
<VirtualMachine moref="#{@vm._ref}">
  <Guest name="#{@vm.config.guestFullName}" family="#{@vm.config.guestId}"/>
  <DataStores>#{ds}</DataStores>
</VirtualMachine>
EOS
    end
    class Property
      attr_reader :moref, :os, :os_family, :datastores
      def initialize(xml)
        @doc = REXML::Document.new(xml)
        @moref = @doc.root.attributes['moref']
        g = @doc.elements['//Guest']
        @os = g.attributes['name']
        @os_family = g.attributes['family']
        @datastores = @doc.elements.collect('//Datastore') do |ds|
          ds.attributes['name']
        end
      end
    end
  end

  class VCenter
    attr_reader :root,:scon,:name,:log

    def initialize(log)
      @log = log
    end

    def path
      "/VC/#{@name}"
    end
    def xml
      ''
    end

    def VCenter.connectParams
      p = VCloudServers.first(:application => 'vCenter')
      [p.host,
       p.account,
       p.password]
    end

    def connect(host,user,pass=nil)
      if(pass.nil?)
        pass = VCloud::SecurePass.new().decrypt(File.new('.vc','r').read)
      elsif (pass.class == File)
        pass = VCloud::SecurePass.new().decrypt(pass.read)
      else
      end

      @name = host

      @vim = RbVmomi::VIM.
        connect({ :host => host, 
                  :user => user, 
                  :password => pass, 
                  :insecure => true,
                })
      @scon = @vim.serviceInstance.content
      @root = @scon.rootFolder
      self
    end

    def vm(moref)
      @index_vm[moref.to_s] || Vm.new
    end

    def media(id)
      @index_media[id] || Media.new
    end

    def load(dir)
      @dir = dir

      @index_vm = {}
      @index_media = {}

      path = "#{dir}/#{self.class.name.sub(/VSphere::/,'')}.xml"
      unless (File.exists?(path))
        return self
      end

      @doc = REXML::Document.new(File.new(path))

      @index_vm = @doc.elements.inject("//HostSystem/VirtualMachine",{}) {|h,e|
        vm = Vm.new
        vm.load(e)
        h.update(e.attributes['moref'] => vm)
        h
      }
      @index_media = @doc.elements.inject("//MediaList/Media",{}) {|h,e|
        m = Media.new
        m.load(e)
        mpath = e.attributes['path']
        (mpath =~ /(\d+)\-media\.iso/ ||  # 1.0
         mpath =~ /media\-(.*)\.iso/) # 1.5
        h.update($1 => m)
        h
      }
      self
    end

    def save(dir)
      if(dir.class == VCloud::Dumper)
        log.info("SAVE: #{self.path}")
        dir.save(self)
        @root.childEntity.grep(RbVmomi::VIM::Datacenter).each do |dc|
          DataCenter.new(self,dc).save(dir)
        end
      else
        xml = ERB.new(File.new("template/vcd-dump/#{self.class.name.sub(/VSphere::/,'')}.erb").read,0,'>').result(binding)
        FileUtils.mkdir_p(dir) unless File.exists? dir
        open("#{dir}/#{self.class.name.sub(/VSphere::/,'')}.xml",'w') {|f| f.puts xml}
      end
    end
  end
end

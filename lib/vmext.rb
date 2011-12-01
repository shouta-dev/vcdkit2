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
require 'rest_client'
require 'rexml/document'
require 'erb'
require 'pp'

require 'vcloud'

module VMExt
  class VmsObjectRefsList < XMLElement
    TYPE='application/vnd.vmware.admin.vmsObjectRefsList+xml'
  end

  class VimServerReferences < XMLElement
    TYPE='application/vnd.vmware.admin.vmwVimServerReferences+xml'
  end

  class ResourcePoolList < XMLElement
    TYPE='application/vnd.vmware.admin.resourcePoolList+xml'
  end

  class VCenter < XMLElement
    TYPE='application/vnd.vmware.admin.vmwvirtualcenter+xml'

    def initialize(vcd,node)
      super
      @rplist = ResourcePoolList.
        new(@vcd,@doc.elements["//vcloud:Link[@type='#{ResourcePoolList::TYPE}']"])
      @vmlist = VmsObjectRefsList.
        new(@vcd,@doc.elements["//vcloud:Link[@type='#{VmsObjectRefsList::TYPE}']"])
    end

    def dump(dir)
      super
      @rplist.dump(dir)
      @vmlist.dump(dir)
    end
  end

  class VSphere
    def initialize(vcd)
      @vcd = vcd
      @xml = vcd.get('https://vcd.vhost.ultina.jp/api/v1.0/admin/extension')
      @doc = REXML::Document.new(@xml)
    end

    def each_vcenter
      vctype='application/vnd.vmware.admin.vmwVimServerReferences+xml'

      REXML::Document.
        new(@vcd.get(@doc.elements["//vcloud:Link[@type='#{vctype}']"].
                     attribute('href').to_s)).
        elements.each("//vmext:VimServerReference") {|n| yield VCenter.new(@vcd,n)}
    end

    def dump(dir)
      self.each_vcenter {|vc| vc.dump("VCENTER/#{vc.name}")}
    end
  end
end





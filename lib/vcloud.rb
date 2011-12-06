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
require 'vclouddata'
require 'pp'

module VCloud
  class InvalidNameException < Exception
  end

  class Task < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.task+xml'
    def status
      if (@doc.nil? || @doc.elements["//Task/@status"].nil?)
        "success"
      else
        @doc.elements["//Task/@status"].value
      end
    end

    def post(vcd,node,payload=nil,hdrs={})
      init_attrs(node)
      @xml = vcd.post(@href,payload,hdrs)
      @doc = REXML::Document.new(@xml)
      self
    end
    def put(vcd,node,payload=nil,hdrs={})
      init_attrs(node)
      @xml = vcd.put(@href,payload,hdrs)
      @doc = REXML::Document.new(@xml)
      self
    end
  end

  class Vdc < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.vdc+xml'

    def initialize(org,name)
      @org = org; @name = name
    end

    def path
      "#{@org.path}/VDC/#{@name}"
    end

    def vapp(name)
      vapp = VApp.new(@org,self,name)
      if(@vcd.connected?)
        vapp.connect(@vcd,@doc.elements["//ResourceEntity[@type='#{VApp::TYPE}' and @name='#{name}']"])
      elsif(@dir)
        vapp.load(@vcd,@dir)
      end
      vapp
    end

    def each_vapp
      @doc.elements.each("//ResourceEntity[@type='#{VApp::TYPE}']"){|n|
        vapp = VApp.new(@org,self,n.attributes['name'].to_s)
        if(@vcd.connected?)
          vapp.connect(@vcd,n)
        elsif(@dir)
          vapp.load(@vcd,@dir)
        end
        yield vapp
      }
    end

    def vapptemplate(name)
      vat = VAppTemplate.new(@org,self,name)
      vat.connect(@vcd,@doc.elements["//ResourceEntity[@type='#{VAppTemplate::TYPE}' and @name='#{name}']"])
    end

    def each_vapptemplate
      @doc.elements.each("//ResourceEntity[@type='#{VAppTemplate::TYPE}']"){|n|
        vat = VAppTemplate.new(@org,self,n.attributes['name'].to_s)
        if(@vcd.connected?)
          vat.connect(@vcd,n)
        elsif(@dir)
          vat.load(@vcd,@dir)
        end
        yield vat
      }
    end

    def save(dir)
      super
      # self.savealt(dir) - TEST ONLY
      self.each_vapp {|vapp| vapp.save(dir)}
      self.each_vapptemplate {|vat| vat.save(dir)}
    end

    def saveparam(dir)
      self.each_vapp {|vapp| vapp.saveparam(dir)}
      self.each_vapptemplate {|vat| vat.saveparam(dir)}
    end

    def cloneVApp(src,name)
      Task.new.post(@vcd,
                    self.alt.elements["//Link[@type='#{CloneVAppParams::TYPE}' and @rel='add']"],
                    CloneVAppParams.new(src,name).xml,
                    {:content_type => CloneVAppParams::TYPE})
    end

    def deployVApp(src,name,desc='')
      Task.new.post(@vcd,
                    self.alt.elements["//Link[@type='#{InstantiateVAppTemplateParams::TYPE}' and @rel='add']"],
                    InstantiateVAppTemplateParams.new(self,src,name,desc).xml,
                    {:content_type => InstantiateVAppTemplateParams::TYPE})
    end

    def composeVApp(src,name)
      Task.new.post(@vcd,
                    self.alt.elements["//Link[@type='#{ComposeVAppParams::TYPE}' and @rel='add']"],
                    ComposeVAppParams.new(src,name).xml,
                    {:content_type => ComposeVAppParams::TYPE})
      
    end
  end

  class Media < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.media+xml'
  end

  class CatalogItem < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.catalogItem+xml'

    def initialize(org,cat,name)
      @org = org; @cat = cat; @name = name
    end
      
    def path
      "#{@cat.path}/CATALOGITEM/#{@name}"
    end

    def type
      @doc.elements['/CatalogItem/Entity/@type'].value
    end

    def id
      href = self.entity_href
      if(href =~ /media\/(\d+)$/)
        sprintf('%010d',$1)
      elsif(href =~ /media\/([0-9a-f\-]+)$/)
        $1
      else
        nil
      end
    end

    def entity_href
      @doc.elements["/CatalogItem/Entity/@href"].value
    end
  end

  class Catalog < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.catalog+xml'

    def initialize(org,name)
      @org = org; @name = name
    end
      
    def path
      "#{@org.path}/CATALOG/#{@name}"
    end

    def catalogitem(name)
      ci = CatalogItem.new(@org,self,name)
      ci.connect(@vcd,@doc.elements["//CatalogItem[@name='#{name}']"])
    end

    def each_catalogitem
      @doc.elements.each("//CatalogItem") do |n|
        ci = CatalogItem.new(@org,self,n.attributes['name'].to_s)
        if(@vcd.connected?)
          ci.connect(@vcd,n)
        elsif(@dir)
          ci.load(@vcd,@dir)
        end
        yield ci
      end
    end

    def save(dir)
      super
      # self.savealt(dir) - TEST ONLY
      self.each_catalogitem {|ci| ci.save(dir)}
    end

    def saveparam(dir)
      # NOT IMPLEMENTED
    end
  end

  class OrgNetwork < XMLElement
    TYPE='application/vnd.vmware.vcloud.network+xml'

    def initialize(org,name)
      @org = org; @name = name
    end

    def path
      "#{@org.path}/ORGNET/#{@name}"
    end
  end

  class Org < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.org+xml'
    attr_reader :org

    def initialize(vcd,name)
      @vcd = vcd
      @name = name
    end

    def path
      "#{@vcd.path}/ORG/#{@name}"
    end

    def vdc(name) 
      vdc = Vdc.new(self,name)
      n = @doc.elements["//Vdcs/Vdc[ @name='#{name}']"]
      if(n.nil?)
        $log.error("Cannot find vdc '#{name}': Available vdcs '#{self.vdcs.join(',')}'")
        raise InvalidNameException.new
      elsif(@vcd.connected?)
        vdc.connect(@vcd,n)
      elsif(@dir)
        vdc.load(@vcd,@dir)
      end
      vdc
    end

    def vdcs 
      @doc.elements.collect("//Vdcs/Vdc") {|n| n.attributes['name']}
    end

    def each_vdc
      @doc.elements.each("//Vdcs/Vdc") {|n| 
        vdc = Vdc.new(self,n.attributes['name'].to_s)
        if(@vcd.connected?)
          vdc.connect(@vcd,n)
        elsif(@dir)
          vdc.load(@vcd,@dir)
        end
        yield vdc
      }
    end

    USERPATH ='//Users/UserReference'

    def user_by_href(href)
      unless(@user_index)
        @user_index = {}
        self.each_user do |u|
          @user_index[u.href] = u
        end
      end
      @user_index[href]
    end

    def user(name)
      name.downcase!
      user = User.new(self,name)
      if(@vcd.connected?)
        user.connect(@vcd,@doc.elements["#{USERPATH}[@name='#{name}']"])
      elsif(@dir)
        user.load(@vcd,"#{@dir}/USER/#{name}")
      end
    end

    def each_user
      @doc.elements.each(USERPATH) { |n| 
        user = User.new(self,n.attributes['name'].to_s)
        if(@vcd.connected?)
          user.connect(@vcd,n)
        elsif(@dir)
          user.load(@vcd,@dir)
        end
        yield user
      }
    end

    def add_user(name,role)
      Task.new.post(@vcd,
                    self.elements["//Link[@type='#{User::TYPE}' and @rel='add']"],
                    User.compose(self,name,role),
                    {:content_type => User::TYPE})
      
    end

    NETWORKPATH ='//Networks/Network'

    def network(name)
      ntwk = OrgNetwork.new
      ntwk.connect(@vcd,@doc.elements["#{NETWORKPATH}[@name='#{name}']"])
    end

    def each_network
      @doc.elements.each(NETWORKPATH) { |n| 
        ntwk = OrgNetwork.new(self,n.attributes['name'].to_s)
        if(@vcd.connected?)
          ntwk.connect(@vcd,n)
        elsif(@dir)
          ntwk.load(@vcd,@dir)
        end
        yield ntwk
      }
    end

    CATPATH = '//Catalogs/CatalogReference'

    def catalog(name)
      cat = Catalog.new(self,name)
      cat.connect(@vcd,@doc.elements["#{CATPATH}[@name='#{name}']"])
    end

    def each_catalog
      @doc.elements.each(CATPATH) {|n| 
        cat = Catalog.new(self,n.attributes['name'].to_s)
        if(@vcd.connected?)
          cat.connect(@vcd,n)
        elsif(@dir)
          cat.load(@vcd,@dir)
        end
        yield cat
      }
    end

    def save(dir)
      super
      # self.savealt(dir) -- TEST ONLY
      self.each_vdc {|vdc| vdc.save(dir)}
      self.each_catalog {|cat| cat.save(dir)}
      self.each_user {|user| user.save(dir)}
      self.each_network {|n| n.save(dir)}
    end

    def saveparam(dir)
      self.each_vdc {|vdc| vdc.saveparam(dir)}
      self.each_catalog {|cat| cat.saveparam(dir)}
    end
  end

  class User < XMLElement
    TYPE='application/vnd.vmware.admin.user+xml'
    XML=<<EOS
<User name="<%= name %>" 
  xmlns="<%= org.xmlns %>">
<FullName><%= name %></FullName>
<EmailAddress><%= name %>@vmware.com</EmailAddress>
<IsEnabled>true</IsEnabled>
<Role type="application/vnd.vmware.admin.role+xml"
  href="<%= role.href %>" name="<%= role.name %>"/>
<Password>password</Password>
</User>
EOS
    def initialize(org,name)
      @org = org; @name = name
    end
      
    def User.compose(org,name,role)
      ERB.new(XML).result(binding)
    end

    def path
      "#{@org.path}/USER/#{@name}"
    end

    def disable
      self.elements['/User/IsEnabled'].text = 'false'
      @vcd.put(self.href,compose_xml(@doc.root,true),{:content_type => TYPE})
    end

    def delete
      @vcd.delete(self.href)
    end
  end

  class Role < XMLElement
    TYPE='application/vnd.vmware.admin.role+xml'

    def initialize(name)
      @name = name
    end
      
    def path
      "#{@vcd.path}/ROLE/#{@name}"
    end
  end

  class VCD < XMLElement
    attr_reader :log

    def initialize(log)
      @log = log
      @vcd = self
      @name = VCloudServers.default('vCD')['host']
    end

    def path
      "/VCD/#{@name}"
    end

    def VCD.connectParams
      p = VCloudServers.first(:application => 'vCD')
      [p.host,
       p.account,
       p.password]
    end

    def connected?
      ! @auth_token.nil?
    end

    def connect(p)
      host = p['host']
      user = p['user']
      pass = p['password']

      versions = REXML::Document.new(self.get("https://#{host}/api/versions")).
        elements.inject('/SupportedVersions/VersionInfo/Version',{}) {|h,vi| h.update(vi.text=>true); h}

      resp = nil
      if(versions['1.5']) 
        @apiurl = "https://#{host}/api"
        resp = RestClient::Resource.new("#{@apiurl}/sessions",
                                        :user => "#{user}@System",
                                        :password => pass).post(nil)

      elsif(versions['1.0'])
        @apiurl = "https://#{host}/api/v1.0"
        resp = RestClient::Resource.new("#{@apiurl}/login",
                                        :user => "#{user}@System",
                                        :password => pass).post(nil)
      else
        raise "No supported API versions found: #{versions.keys.join(',')}"
      end
      @auth_token = {:x_vcloud_authorization => resp.headers[:x_vcloud_authorization]}

      @xml = self.get("#{@apiurl}/admin")
      @doc = REXML::Document.new(@xml)
      self
    end

    def load(dir,*target)
      super(self,dir,*target)
      # @name is overwritten with name attribute of root node. So reset it.
      @name = VCloudServers.default('vCD')['host']
      @auth_token = nil
      self
    end

    def save(dir)
      super
      self.each_org {|org| org.save(dir)}
      self.each_role {|role| role.save(dir)}
    end

    def saveparam(dir)
      self.each_org {|org| org.saveparam(dir)}
    end

    ROLEPATH ='//RoleReferences/RoleReference'

    def role(name)
      role = Role.new(name)
      if(connected?)
        role.connect(self,@doc.elements["#{ROLEPATH}[@name='#{name}']"])
      elsif(@dir)
        role.load(@vcd,@dir)
      end
    end

    def each_role
      @doc.elements.each(ROLEPATH) { |n| 
        role = Role.new(n.attributes['name'].to_s)
        if(connected?)
          role.connect(self,n)
        elsif(@dir)
          role.load(@vcd,@dir)
        end
        yield role
      }
    end

    ORGPATH='//OrganizationReferences/OrganizationReference'

    def org(name)
      org = Org.new(self,name)
      if(connected?)
        org.connect(self,@doc.elements["#{ORGPATH}[@name='#{name}']"])
      else
        org.load(@vcd,@dir)
      end
    end

    def each_org
      @doc.elements.each(ORGPATH) { |n| 
        org = Org.new(self,n.attributes['name'])
        if(connected?)
          org.connect(self,n)
        elsif(@dir)
          org.load(@vcd,@dir)
        end
        yield org
      }
    end

    def get(url)
      log.info("HTTP GET: #{url.sub(/#{@apiurl}/,'')}")
      RestClient.get(url,@auth_token) { |response, request, result, &block|
        case response.code
        when 200..299
          response
        else
          log.error("#{response.code}>> #{response}")
          response.return!(request,result,&block)
        end
      }
    end

    def delete(url)
      log.info("HTTP DELETE: #{url.sub(/#{@apiurl}/,'')}")
      RestClient.delete(url,@auth_token) { |response, request, result, &block|
        case response.code
        when 200..299
          response
        else
          log.error("#{response.code}>> #{response}")
          response.return!(request,result,&block)
        end
      }
    end

    def post(url,payload=nil,hdrs={})
      log.info("HTTP POST: #{url.sub(/#{@apiurl}/,'')}")
      RestClient.post(url,payload,hdrs.update(@auth_token)) { |response, request, result, &block|
        case response.code
        when 200..299
          response
        else
          log.error("#{response.code}<< #{payload}")
          log.error("#{response.code}>> #{response}")
          response.return!(request,result,&block)
        end
      }
    end

    def put(url,payload=nil,hdrs={})
      log.info("HTTP PUT: #{url.sub(/#{@apiurl}/,'')}")
      RestClient.put(url,payload,hdrs.update(@auth_token)) { |response, request, result, &block|
        case response.code
        when 200..299
          response
        else
          log.error("#{response.code}<< #{payload}")
          log.error("#{response.code}>> #{response}")
          response.return!(request,result,&block)
        end
      }
    end

    def wait(task)
      while task.status == 'running'
        sleep(3)
        node = task.doc.root
        task = Task.new
        task.connect(self,node)
      end
      if(task.status != 'success')
        log.warn("Task failed to complete:")
        log.warn(task.xml)
      end
    end  
  end
end

def vcdopts(options,opt) 
  opt.on('-v','--vcd HOST,ORG,USER',Array,'vCD login parameters') do |o|
    if(o[0].size == 1)
      options[:vcd] = $VCD[o[0].to_i - 1]
    else
      options[:vcd] = o
    end
  end
end

def vcopts(options,opt)
  opt.on('-c','--vcenter HOST,USER',Array,'vCenter login parameters') do |o|
    if(o[0].size == 1)
      options[:vsp] = $VSP[o[0].to_i - 1]
    else
      options[:vsp] = o
    end
  end
end



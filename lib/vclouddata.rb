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
require 'data_mapper'
require 'erb'
require 'pp'

class DumpTree
  include DataMapper::Resource
  property :id, Serial
  property :jobid, Integer
  property :created_at, DateTime
end

class DumpData
  include DataMapper::Resource
  property :id, Serial
  property :treeid, Integer
  property :created_at, DateTime
  property :type, String
  property :name, String
  property :path, Text
  property :xml, Text
end

class VCloudServers
  include DataMapper::Resource
  property :id, Serial
  property :application, String
  property :host, String
  property :account, String
  property :password, String

  def VCloudServers.default(app)
    YAML::load(File.new(File.dirname(__FILE__) + 
                        "/../config/vcloud_servers.yml").read).each do |cfg|
      return [cfg['host'],cfg['account'],cfg['password']] if cfg['application'] == app
    end
    return nil
  end
end

class XMLElement
  ATTRS = [:name, :href]
  attr_accessor(*ATTRS)
  attr_reader :xml, :doc, :xmlns, :vmext

  def init_attrs(node,attrs=ATTRS)
    attrs.each { |attr|
      s_attr = attr.to_s
      if (node.attributes[s_attr])
        s_attr.sub!(/^\S+\:/,'')
        eval "@#{s_attr} = node.attributes['#{s_attr}']"
      elsif (node.elements[s_attr])
        eval "@#{s_attr} = node.elements['#{s_attr}'].text"
      end
    }
  end

  def connect(vcd,node)
    init_attrs(node)
    @vcd = vcd
    @xml = vcd.get(@href)
    @doc = REXML::Document.new(@xml)
    init_attrs(@doc.root,[:xmlns,:'xmlns:vmext',:id])
    self
  end

  def parse(xml)
    @xml = xml
    @doc = REXML::Document.new(@xml)
    init_attrs(@doc.root,[:xmlns,:'xmlns:vmext',:id])
    self
  end

  def load(dir)
    @vcd.log.info("LOAD: #{self.path}/#{self.basename}")

    file = "#{dir}/#{self.path}/#{self.basename}"
    @dir = dir
    begin
      @doc = REXML::Document.new(File.new(file))
      init_attrs(@doc.root,ATTRS + [:xmlns,:'xmlns:vmext'])
    rescue Exception => e
      @vcd.log.error("Failed to load xml file: #{file}: #{e}")
    end
    self
  end

  def short_classname()
    self.class.name.sub(/VCloud::/,'')
  end
  def basename()
    self.short_classname + ".xml"
  end
  def altname()
    self.short_classname + "Alt.xml"
  end
  def paramsname()
    self.short_classname + "Params.xml"
  end

  def save(dir)
    @vcd.log.info("SAVE: #{self.path}/#{self.basename}")
    if (dir.class == VCloud::Dumper)
      dir.save(self)
    else
      dir = "#{dir}/#{self.path}"
      FileUtils.mkdir_p(dir) unless File.exists? dir
      path = "#{dir}/#{self.basename}"
      open(path,'w') {|f| f.puts @xml}
    end
  end

  def savealt(dir)
    @vcd.log.info("SAVEALT: #{self.path}/#{self.altname}")

    dir = "#{dir}/#{self.path}"
    FileUtils.mkdir_p(dir) unless File.exists? dir
    path = "#{dir}/#{self.altname}"
    xml = @vcd.get(@doc.elements["//Link[@rel='alternate']/@href"].value)
    open(path,'w') {|f| f.puts xml}
  end

  def saveparam(dir)
    @vcd.log.info("SAVE: #{self.path}/#{self.paramsname}")

    dir = "#{dir}/#{self.path}"
    FileUtils.mkdir_p(dir) unless File.exists? dir
    path = "#{dir}/#{self.paramsname}"
    begin
      open(path,'w') do |f|
        erb = File.new("template/vcd-report/#{self.paramsname.sub('.xml','.erb')}").read
        xml = ERB.new(erb,0,'>').result(binding)
        doc = REXML::Document.new(xml)
        REXML::Formatters::Pretty.new.write(doc.root,f)
      end
    rescue Exception => e
      @vcd.log.warn("Failed to save parameters: #{path}: #{e}")
      @vcd.log.warn(e.backtrace)
    end
  end

  def [](xpath)
    @doc.elements[xpath]
  end
  def elements
    @doc.elements
  end
  def match(xpath)
    REXML::XPath.match(@doc,xpath)
  end
  def alt
    REXML::Document.new(@vcd.get(@doc.elements["//Link[@rel='alternate']/@href"].value))
  end

  def compose_xml(node,hdr=true)
    xml = ''
    if(hdr)
      xml = '<?xml version="1.0" encoding="UTF-8"?>'
      node.attributes['xmlns'] = @xmlns
      node.attributes['xmlns:ovf'] ='http://schemas.dmtf.org/ovf/envelope/1'
      node.attributes['xmlns:vmext'] = @vmext
    end
    REXML::Formatters::Default.new.write(node,xml)
    xml
  end
end

module VCloud
  class GuestCustomizationSection < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.guestCustomizationSection+xml'
    XML=<<EOS
<GuestCustomizationSection>
  <ChangeSid>true</ChangeSid>
  <AdminPasswordEnabled>true</AdminPasswordEnabled>
  <AdminPasswordAuto>false</AdminPasswordAuto>
  <AdminPassword><%= args['AdminPassword'] %></AdminPassword>
  <ResetPasswordRequired>false</ResetPasswordRequired>
  <ComputerName><%= args['ComputerName'] %></ComputerName>
</GuestCustomizationSection>
EOS
  #  <UseOrgSettings>false</UseOrgSettings>
  # <JoinDomainEnabled>true</JoinDomainEnabled>
  # <DomainName><%= args['DomainName'] %></DomainName>
  # <DomainUserName><%= args['DomainUserName'] %></DomainUserName>
  # <DomainUserPassword><%= args['DomainUserPassword'] %></DomainUserPassword>

    def initialize(vm,node)
      @vm = vm
      @node = node.elements['//GuestCustomizationSection']
      @node.elements.delete('./VirtualMachineId')
      @node.elements.delete('./Link')
      pass = @node.elements['./AdminPassword/text()']
      if(pass != nil && pass != '')
        @node.elements['./AdminPasswordAuto'].text = 'false'
      end
      if(@node.elements['//JoinDomainEnabled'].text == 'false')
        ['DomainName','DomainUserName','DomainUserPassword'].each do |d|
          @node.elements.delete("//#{d}")
        end
      end
    end
    
    def extractParams
      @node.attributes.each {|name,value| @node.attributes.delete(name)}
      @node.elements.delete('./VirtualMachineId')
      @node.elements.delete('./ovf:Info')
      @node.elements.delete('./Link')
      pass = @node.elements['./AdminPassword/text()']
      if(pass != '')
        @node.elements.delete('./AdminPasswordAuto')
      end
      self
    end

    def xml(hdr)
      @vm.compose_xml(@node,hdr)
    end

    def GuestCustomizationSection.compose(node,args)
      new = ERB.new(XML).result(binding)
      
      doc = REXML::Document.new(new)
      prev = nil
      doc.elements.each("/GuestCustomizationSection/*") do |e|
        n = node.elements[e.name]
        if n.nil?
          n = prev.next_sibling = REXML::Element.new(e.name)
        end
        n.text = e.text
        prev = n
      end
    end
  end

  class OperatingSystemSection < XMLElement    
    TYPE = 'application/vnd.vmware.vcloud.operatingSystemSection+xml'

    def initialize(vm,node)
      @vm = vm
      @node = node.elements['//ovf:OperatingSystemSection']
      @node.elements.delete('./Link')
      @node.attributes.delete('vcloud:href')
    end

    def xml(hdr)
      @vm.compose_xml(@node,hdr)
    end
  end

  class NetworkConnection < XMLElement    
    def initialize(node)
      @node = node
    end

    def extractParams
      @node.elements.delete('./ExternalIpAddress')
      @node.attributes.delete('needsCustomization')
      self
    end

    def xml(hdr)
      self.compose_xml(@node,hdr)
    end
  end

  class NetworkConnectionSection < XMLElement    
    TYPE = 'application/vnd.vmware.vcloud.networkConnectionSection+xml'
    EMPTYXML = <<EOS
<NetworkConnectionSection 
  xmlns="<%= vm.xmlns %>"
  xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1"
  type="application/vnd.vmware.vcloud.networkConnectionSection+xml"
  ovf:required="false">
<ovf:Info>Specifies the available VM network connections</ovf:Info>
</NetworkConnectionSection>
EOS
    def initialize(vm,node)
      @vm = vm
      if(node)
        @node = node.elements['//NetworkConnectionSection']
      else
        @emptyxml = ERB.new(EMPTYXML).result(binding)
      end
    end

    def extractParams
      @node.elements.each('./NetworkConnection') do |n|
        n.elements.delete('./ExternalIpAddress')
      end
      self
    end

    def xml(hdr)
      if(@node)
        @vm.compose_xml(@node,hdr)
      else
        @emptyxml
      end
    end
  end


  class NetworkConfigSection < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.networkConfigSection+xml'

    def initialize(vapp,node)
      @vapp = vapp
      @node = node.elements['//NetworkConfigSection']

      dhcp = @node.elements.each("//DhcpService[IsEnabled = 'false']") do |dhcp|
        dhcp.elements.each('./*') do |n|
          next if n.name == 'IsEnabled'
          dhcp.delete(n)
        end
      end
    end

    def extractParams
      @node.attributes.each {|name,value| @node.attributes.delete(name)}
      ['./ovf:Info','./Link'].each do |n|
        @node.elements.delete(n)
      end
      @node.elements.each('.//Configuration') do |n|
        n.elements.delete('.//AllocatedIpAddresses')
        n.elements.delete('./ParentNetwork')
        n.elements.delete('./RouterInfo')
      end
      @node.elements.each('.//OneToOneVmRule') do |n|
        n.elements.delete('./VAppScopedVmId')
        n.elements.delete('./ExternalIpAddress')
      end
      @node.elements.each('.//IpScope') do |n|
        n.elements.delete('./IsInherited')
      end
      @node.elements.each('.//NetworkConfig') do |n|
        n.elements.each('./Link') do |l|
          n.elements.delete(l)
        end
        n.elements.delete('./VCloudExtension')
        n.elements.delete('./IsDeployed')
      end
      self
    end

    def xml(hdr)
      @vapp.compose_xml(@node,hdr)
    end
  end

  class StartupSection < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.startupSection+xml'
  end

  class LeaseSettingsSection < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.leaseSettingsSection+xml'

    def initialize(vapp,node)
      @vapp = vapp
      @node = node.elements['//LeaseSettingsSection']
    end

    def extractParams
      @node.name = 'Lease'
      @node.attributes.each {|name,value| @node.attributes.delete(name)}
      ['./ovf:Info',
       'Link',
       'StorageLeaseExpiration',
       'DeploymentLeaseExpiration'].each {|n| @node.elements.delete(n)}
      self
    end

    def xml(hdr)
      @vapp.compose_xml(@node,hdr)
    end
  end

  class AccessSetting < XMLElement
    def initialize(vapp,node)
      @vapp = vapp
      @node = node
    end

    def extractParams
      sub = @node.elements['./Subject']
      sub.attributes.delete('type')
      sub.text = @vapp.org.user_by_href(sub.attributes['href']).name
      sub.attributes.delete('href')
      self
    end

    def xml(hdr)
      @vapp.compose_xml(@node,hdr)
    end
  end

  class Owner < XMLElement
    TYPE='application/vnd.vmware.vcloud.owner+xml'
  end


  class DeployVAppParams < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.deployVAppParams+xml'
    XML =<<EOS
<DeployVAppParams powerOn="true" xmlns="http://www.vmware.com/vcloud/v1"/>
EOS
    def initialize()
      @xml = ERB.new(XML).result(binding)
    end
  end

  class UndeployVAppParams < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.undeployVAppParams+xml'
    XML =<<EOS
<UndeployVAppParams xmlns="<%= vapp.xmlns %>"/>
EOS
    def initialize(vapp)
      @xml = ERB.new(XML).result(binding)
    end
  end

  class ComposeVAppParams < XMLElement
    TYPE='application/vnd.vmware.vcloud.composeVAppParams+xml'
    XML =<<EOS
<ComposeVAppParams name="<%= self.name %>" 
  xmlns="http://www.vmware.com/vcloud/v1"
  xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1"> 
<InstantiationParams>
  <%= self.compose_xml(ntwkcfg,false) %>
</InstantiationParams>
</ComposeVAppParams>

EOS
    def initialize(src,name)
      @name = name
      ntwkcfg = src.doc.elements['/VApp/NetworkConfigSection']
      ntwkcfg.elements.delete('//IpRange[not(node())]')

      @xml = ERB.new(XML).result(binding)
      @doc = REXML::Document.new(@xml)
    end
  end

  class EditVAppParams < XMLElement
    TYPE='application/vnd.vmware.vcloud.vApp+xml'
    XML =<<EOS
<VApp name="<%= src.doc.root.attributes['name'] %>" 
  xmlns="<%= vapp.xmlns %>"
  xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1"> 
<Description><%= src['/VApp/Description/text()'] %></Description>
</VApp>
EOS
    def initialize(vapp,src)
      @xml = ERB.new(XML).result(binding)
      @doc = REXML::Document.new(@xml)
    end
  end

  class EditVmParams < XMLElement
    TYPE='application/vnd.vmware.vcloud.vm+xml'
    XML =<<EOS
<Vm name="<%= src.doc.root.attributes['name'] %>" 
  xmlns="<%= vm.xmlns %>"
  xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1"> 
<Description><%= src['/Vm/Description/text()'] %></Description>
</Vm>
EOS
    def initialize(vm,src)
      @xml = ERB.new(XML).result(binding)
      @doc = REXML::Document.new(@xml)
    end
  end

  class RecomposeVAppParams < XMLElement
    TYPE='application/vnd.vmware.vcloud.recomposeVAppParams+xml'
    XML =<<EOS
<RecomposeVAppParams name="<%= src.doc.root.attributes['name'] %>" 
  xmlns="<%= vapp.xmlns %>"
  xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1"> 
<InstantiationParams>
  <%= LeaseSettingsSection.new(src['/VApp/LeaseSettingsSection']).xml(false) %>
  <%= NetworkConfigSection.new(src['/VApp/NetworkConfigSection']).xml(false) %>
</InstantiationParams>
</RecomposeVAppParams>
EOS
    def initialize(vapp,src)
      @xml = ERB.new(XML).result(binding)
      @doc = REXML::Document.new(@xml)
    end
  end

  class InstantiateVAppTemplateParams < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.instantiateVAppTemplateParams+xml'
    XML =<<EOS
<?xml version="1.0" encoding="UTF-8"?>
<InstantiateVAppTemplateParams 
  name="<%= name %>" 
  deploy="true"
  powerOn="true"
  xmlns="<%= vdc.xmlns %>"
  xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1"> 
  <Description><%= desc %></Description> 
  <Source href="<%= src.href %>"/>
</InstantiateVAppTemplateParams>
EOS
  # <InstantiationParams>
  #   <NetworkConfigSection> 
  #     <ovf:Info/>
  #     <NetworkConfig networkName="<%= ntwk.name %>">
  #       <Configuration>
  #         <ParentNetwork href="<%= ntwk.href %>"/>
  #         <FenceMode>bridged</FenceMode>
  #       </Configuration>
  #     </NetworkConfig>
  #   </NetworkConfigSection>
  # </InstantiationParams>

    def initialize(vdc,src,name,desc)
      @xml = ERB.new(XML).result(binding)
    end
  end

  class CloneVAppParams < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.cloneVAppParams+xml'
    XML =<<EOS
<?xml version="1.0" encoding="UTF-8"?>
<CloneVAppParams 
  name="<%= name %>" 
  xmlns="<%= vapp.xmlns %>">
<Description/>
<Source href="<%= vapp.href %>"/>
<IsSourceDelete>false</IsSourceDelete>
</CloneVAppParams>
EOS
    def initialize(vapp,name)
      @xml = ERB.new(XML).result(binding)
      @doc = REXML::Document.new(@xml)
    end
  end

end

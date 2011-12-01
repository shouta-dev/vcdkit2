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

module VShieldManager

  class VShieldEdge 
    attr_reader :name,:id

    def initialize(vsm,id)
      @vsm = vsm
      @id = id

      @doc = REXML::Document.new(@vsm.get("networks/#{@id}/edge"))
      @name = @doc.elements['//hostName'].text
    end

    def dhcpService
      doc = REXML::Document.new(@vsm.get("networks/#{@id}/edge/dhcp/service"))
      doc.elements['//dhcpService'].text
    end

    def serviceStats
      doc = REXML::Document.new(@vsm.get("networks/#{@id}/edge/serviceStats"))
      doc.elements['//serviceStatsLocation'].text
    end
  end

  class VSM < XMLElement
    def connect(host,user)
      @url_base = "https://#{host}/api/2.0"

      pass = VCloud::SecurePass.new().decrypt(File.new('.vsm','r').read)
      auth = Base64.encode64("#{user}:#{pass}")
      @auth_token = {:Authorization => "Basic #{auth}"}

      @xml = self.get("networks/edge/capability")
      @doc = REXML::Document.new(xml)
    end

    def each_vse
      @doc.root.elements.each('//networkId') do |n|
        yield VShieldEdge.new(self,n.text)
      end
    end

    def get(url)
      $log.info("HTTP GET: #{url}")
      RestClient.get("#{@url_base}/#{url}",@auth_token) { |response, request, result, &block|
        case response.code
        when 200..299
          response
        else
          $log.error("#{response.code}>> #{response}")
          response.return!(request,result,&block)
        end
      }
    end
  end
end

def vsmopts(options,opt)
  opt.on('','--vsm HOST,USER',Array,'vShield Manager login parameters') do |o|
    if(o[0].size == 1)
      options[:vsm] = $VSM[o[0].to_i - 1]
    else
      options[:vsm] = o
    end
  end
end


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
require 'oci8'
require 'yaml'
require 'pp'

module Chargeback

  class Task < XMLElement
	XML=<<EOS
  <QueuedTasks>
    <QueuedTask id="433" type="EXPORT_REPORT">
      <Status>QUEUED</Status>
      <Progress>0.0</Progress>
      <CreatedOn>1311302010358</CreatedOn>
      <CreatedBy>1</CreatedBy>
      <CreatedByName>vcdadmin</CreatedByName>
      <ModifiedOn>1311302010358</ModifiedOn>
      <ModifiedBy />
      <Result>
        <Report id="10670">
          <Hierarchy id="">
            <Name />
          </Hierarchy>
        </Report>
      </Result>
    </QueuedTask>
  </QueuedTasks>
</Response>
EOS
    def status
    end
  end

# <Request xmlns="http://www.vmware.com/vcenter/chargeback/1.5.0">
  class LoginParam < XMLElement
    XML=<<EOS
<?xml version="1.0" encoding="UTF-8"?>
<Request>
  <Users>
    <User>
      <Type>local</Type>
      <Name><%= user %></Name>
      <Password><%= pass %></Password>
    </User>
  </Users>
</Request>
EOS
    def initialize(user,pass)
      @xml = ERB.new(XML).result(binding)
    end
  end


  class SearchReportParam < XMLElement
    XML=<<EOS
<?xml version="1.0" encoding="UTF-8"?>
<Request>
<SearchQueries>
  <SearchQuery id="report">
    <Criteria type="AND">
      <Filter name="name" type="LIKE" value="<%= name %>" /> 
    </Criteria>
    <Pagination>
      <FirstResultCount>0</FirstResultCount>
      <MaxResultCount>100</MaxResultCount>
    </Pagination> 
  </SearchQuery>
</SearchQueries>
</Request>
EOS
    def initialize(name)
      @xml = ERB.new(XML).result(binding)
    end
  end

  class VCBDB
    attr_reader :conn   
    TIMEFORMAT = '%Y-%m-%d %H:%M:%S'

    class DCThread
      attr_reader :name,:lastProcessTime
      INIT =<<EOS
SELECT server_property_value
FROM cb_server_property
WHERE server_property_name like '<%= name %>'
EOS
      def initialize(conn,name)
        sql = ERB.new(INIT).result(binding)
        @name = name
        conn.exec(sql) do |r|
          @lastProcessTime = Time.at(Integer(r[0])/1000)
        end
      end
    end
    
    class FixedCost
      NULLTS = '9999-11-30 23:59:59'
      COLS = 'entity_id, cost_model_id, global_fc_line_item_id, start_time, end_time, propagate'
      INSERT = <<EOS
INSERT INTO cb_fixed_cost (#{COLS})
VALUES (<%= @heid %>,<%= @cmid %>,<%= @fcid %>,<%= start_sql %>,<%= end_sql %>,0)
EOS
      attr_reader :heid,:cmid,:fcid,:start,:end

      def initialize(heid,cmid,fcid,start,e,*ignore)
        @heid = heid
        @cmid = cmid
        @fcid = fcid
        @start = start
        @start = DateTime.parse(@start) if @start.class == String
        @end = e || NULLTS
        @end = DateTime.parse(@end) if @end.class == String
      end

      def start_sql
        "to_date('#{@start.strftime(TIMEFORMAT)}','YYYY-MM-DD HH24:MI:SS')"
      end

      def end_sql
        if(@end == DateTime.parse(NULLTS))
          'NULL'
        else
          "to_date('#{@end.strftime(TIMEFORMAT)}','YYYY-MM-DD HH24:MI:SS')"
        end
      end

      def ==(other)
        (self.heid == other.heid &&
         self.cmid == other.cmid &&
         self.fcid == other.fcid &&
         self.start.strftime(TIMEFORMAT) == other.start.strftime(TIMEFORMAT) &&
         self.end.strftime(TIMEFORMAT) == other.end.strftime(TIMEFORMAT))
      end

      def insert
        ERB.new(INSERT).result(binding)
      end

      def to_s
        "#{@heid},#{@cmid},#{@fcid},#{@start.strftime(TIMEFORMAT)},#{@end.strftime(TIMEFORMAT)}"
      end

      def FixedCost.search(conn,heid)
        conn.exec("SELECT #{COLS} FROM cb_fixed_cost WHERE entity_id=#{heid}") do |r|
          yield FixedCost.new(*r)
        end
      end
    end

    class VM
      SEARCH_BY_STARTTIME = <<EOS
SELECT che.cb_hierarchical_entity_id heid,
       ch.hierarchy_name org, 
       ce2.entity_name vapp,
       che.entity_display_name vm, 
       chr.start_time created, 
       chr.end_time deleted
FROM cb_hierarchy_relation chr 
  INNER JOIN cb_hierarchical_entity che 
    ON chr.entity_id = che.cb_hierarchical_entity_id
  INNER JOIN cb_entity ce 
    ON che.entity_id = ce.entity_id
  INNER JOIN cb_hierarchy ch
    ON che.hierarchy_id = ch.hierarchy_id
  INNER JOIN cb_hierarchical_entity che2
    ON chr.parent_entity_id = che2.cb_hierarchical_entity_id
  INNER JOIN cb_entity ce2
    ON che2.entity_id = ce2.entity_id
WHERE chr.start_time > to_date('<%= t0 %>', 'YYYY-MM-DD HH24:MI:SS') 
  AND chr.start_time < to_date('<%= t1 %>', 'YYYY-MM-DD HH24:MI:SS') 
  AND end_time is not null
  AND ce.entity_type_id = 0
ORDER BY ch.hierarchy_name, chr.start_time
EOS

      SEARCH_PARENT = <<EOS
SELECT che2.cb_hierarchical_entity_id,
       ce2.entity_name
FROM cb_hierarchy_relation chr
  INNER JOIN cb_hierarchical_entity che
    ON chr.entity_id = che.cb_hierarchical_entity_id
  INNER JOIN cb_hierarchical_entity che2
    ON chr.parent_entity_id = che2.cb_hierarchical_entity_id
  INNER JOIN cb_entity ce2 
    ON che2.entity_id = ce2.entity_id
WHERE che.cb_hierarchical_entity_id = <%= heid %>
EOS

      attr_reader :heid,:org,:vapp,:name,:created,:deleted

      def initialize(conn,heid,org,vapp,name,created,deleted)
        @conn = conn
        @heid = heid
        @org = org
        @vapp = vapp
        @name = name
        @created = created
        @deleted = deleted
      end

      def VM.searchByStartTime(conn,opts)
        t0 = opts[:t0].strftime('%Y-%m-%d %H:%M:%S')
        t1 = opts[:t1].strftime('%Y-%m-%d %H:%M:%S')
        sql = ERB.new(SEARCH_BY_STARTTIME).result(binding)
        conn.exec(sql) do |r|
          next if r[1] =~ /^DELETED/
          yield VM.new(conn,*r)
        end
      end

      def vdc
        if @vdc.nil?
          heid = @heid

          sql = ERB.new(SEARCH_PARENT).result(binding)
          @conn.exec(sql) {|r| heid = r[0]}
          sql = ERB.new(SEARCH_PARENT).result(binding)
          @conn.exec(sql) {|r| heid = r[0]}
          sql = ERB.new(SEARCH_PARENT).result(binding)
          @conn.exec(sql) {|r| @vdc = r[1].chomp}
        end
        @vdc
      end

      def each_fixedcost
        FixedCost::search(@conn,@heid) do |fc|
          yield fc
        end
      end

      def each_vmicost
        cost_model_ids = []
        @conn.exec('SELECT cost_model_id FROM cb_vmi_cm_matrix_map') do |r|
          cost_model_ids.push(r[0])
        end
        cost_model_ids.each do |cmid|
          heid = @heid
          sql = ERB.new(File.new("support/vcb/list_vmi_cost.sql").read).result(binding)
          curs = @conn.parse(sql)
          curs.bind_param(':fixed_costs','INIT')
          curs.exec()
          YAML.load(curs[':fixed_costs']).each do |fc|
            yield FixedCost.new(fc[:heid],fc[:cmid],fc[:fcid],fc[:start],fc[:end])
          end
        end
      end
    end

    def connect(host,dbname)
      pass = VCloud::SecurePass.new().decrypt(File.new('.vcbdb','r').read)
      c = 0
      while @conn.nil? && c<5
        begin 
          @log.info("Connecting VCB database #{host}/#{dbname}")
          @conn = OCI8.new('vcb',pass,"//#{host}/#{dbname}")
        rescue Exception => e
          @log.info("#{e}")
          sleep(3)
          c += 1
        end
      end
      @conn
    end

    def initialize(log)
      @log = log
    end

    def dcThreads
      ['vmijob.lastProcessTime',
       'cbEventListRawView.lastProcessTime',
       'vcLastProcessTime-%'].collect do |name|
        DCThread.new(@conn,name)
      end
    end

    def lastFixedCost
      t = nil
      conn.exec('SELECT MAX(start_time) FROM cb_fixed_cost') {|r| t = r[0]}
      t
    end
  end

  class VCB < XMLElement
    def connect(host,user)
      pass = VCloud::SecurePass.new().decrypt(File.new('.vcb','r').read)
      @url = "https://#{host}/vCenter-CB/api"
      resp = self.post("#{@url}/login",LoginParam.new(user,pass).xml)
      @cookies = resp.cookies 
      self
    end

    def searchReport(name)
      resp = self.post("#{@url}/search",SearchReportParam.new(name).xml)
      @xml = resp.body
      @doc = REXML::Document.new(@xml)
      @doc.elements.collect("//Report") {|r| r.attributes['id']}
    end

    def exportReport(id)
      resp = self.get("#{@url}/report/#{id}/export?exportFormat=XML")
      @xml = resp.body
      puts @xml
      @doc = REXML::Document.new(@xml)
    end

    def get(url)
      $log.info("HTTP GET: #{url}")
      hdrs = {:cookies => @cookies} if @cookies
      RestClient.get(url,hdrs) { |response, request, result, &block|
        case response.code
        when 200..299
          response
        else
          $log.error("#{response.code}>> #{response}")
          response.return!(request,result,&block)
        end
      }
    end

    def delete(url)
      $log.info("HTTP DELETE: #{url}")
      hdrs = {:cookies => @cookies} if @cookies
      RestClient.delete(url,hdrs) { |response, request, result, &block|
        case response.code
        when 200..299
          response
        else
          $log.error("#{response.code}>> #{response}")
          response.return!(request,result,&block)
        end
      }
    end

    def post(url,payload=nil,hdrs={})
      $log.info("HTTP POST: #{url}")
      hdrs.update(:cookies => @cookies) if @cookies
      RestClient.post(url,payload,hdrs) { |response, request, result, &block|
        case response.code
        when 200..299
          response
        else
          $log.error("#{response.code}<< #{payload}")
          $log.error("#{response.code}>> #{response}")
          response.return!(request,result,&block)
        end
      }
    end

    def put(url,payload=nil,hdrs={})
      $log.info("HTTP PUT: #{url}")
      hdrs.update(:cookies => @cookies) if @cookies
      RestClient.put(url,payload,hdrs) { |response, request, result, &block|
        case response.code
        when 200..299
          response
        else
          $log.error("#{response.code}<< #{payload}")
          $log.error("#{response.code}>> #{response}")
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
    end  
  end
end


# encoding: UTF-8

require 'riak'
require 'yajl'
require 'uri'
require 'debugger'
require "base64"
require 'yajl/json_gem' # MULTIJSON is a bad kitty # yajl can replace it with this line 

$client = Riak::Client.new(:http_backend => :Excon)

class Time
  def to_ms
    (self.to_f * 1000.0).to_i
  end
end

def write_request(record,record_index = false) 

  # include the index in the object
  #
  record.merge!(record_index) if record_index

    bucket = $client.bucket('requests')
    object = bucket.get_or_new(record['key'])
    object.raw_data = str = Yajl::Encoder.encode(record)
    object.content_type = 'application/json'
    object.indexes = record_index if record_index
    object.store
    puts "stored request"
end


TRAFFIC_COMPLETE='traffic-completed-at-ms'

require 'thin'
module Thin
  class Connection

    def proxy_record
      @request.proxy_record
    end

    def proxy_record_index
      @request.proxy_record_index
    end

    alias :thin_connection_post_init :post_init
    def post_init(*args)
      @one = 1


      retval = thin_connection_post_init(*args)

      # initial request has been created
      @request.start_proxy_record
      #  write_request(proxy_record,proxy_record_index)
      return  retval
    end

    alias :thin_connection_receive_data :receive_data
    def receive_data(*args)
      @two = 1

      retval = thin_connection_receive_data(*args)

      return  retval
    end

    alias :thin_connection_unbind :unbind
    def unbind(*args)
      #
      # two strange situations
      #
      # Unbind is not getting called -- http clients seem to leave the connection open
      #
      # Unbind is getting called on quick open/close that comes with client request
      #
      proxy_record['connection-unbound-at'] = Time.now.to_ms

    #  write_request(proxy_record,proxy_record_index)
      retval = thin_connection_unbind(*args)
      return  retval
    end

  end
end

module Thin
  class Request
    attr_accessor :proxy_record,:proxy_record_index

    def raw_receive_count
      @raw_receive_count  ||= 0
    end

    def next_raw_receive_count 
      @raw_receive_count = @raw_receive_count + 1
    end
    def commit_proxy_record
      self.proxy_record_index['request-complete_int'] = 1
      self.proxy_record_index['completed-at-ms_int'] =
        Time.now.to_ms

      dur = self.proxy_record['request-duration-ms'] =
        self.proxy_record_index['completed-at-ms_int'] -
        self.proxy_record_index['created-at-ms_int']


      p self.proxy_record_index['completed-at-ms_int']
      p self.proxy_record_index['created-at-ms_int']

      #
      #
      #
      # BUG : duration is not being  measured correctly
      #
      puts "Request Duration: #{dur} milliseconds"

      write_request(self.proxy_record,self.proxy_record_index)
    end

    def start_proxy_record
      @raw_receive_count  = 0
      # index gets timestamp and remote_ip
      self.proxy_record_index = {
        'created-at-ms_int' => Time.now.to_ms,
        'remote-ip_bin' => @env[REMOTE_ADDR]
      }
      #
      # CREATED_PHASE
      #
      # starts out with TRAFFIC_COMPLETE -1
      #
      
      self.proxy_record = {
        'key' => $client.stamp.next,
        TRAFFIC_COMPLETE => -1,
      }

    end

    alias :thin_request_parse :parse
    def parse(data)
      @env['thin.request'] = self
      databits = data.encode(Encoding::ASCII_8BIT)
      self.proxy_record["receive-data-#{raw_receive_count}_base64"] = Base64.encode64(databits) # data

      # encoding is not getting set properly
      #process_write_to_file.rb:58:in `parse': lexical error: invalid bytes in UTF8 string. (Yajl::ParseError)
      #
      ##  this fails in trying to force binary encoding
      #self.proxy_record["receive-data-#{raw_receive_count}_bin"] = databits.unpack("C*").pack("C*")
      # this also fails in trying to force binary encoding
      # unicode bytes are not breaking apart
      ##self.proxy_record["receive-data-#{raw_receive_count}_bin"].encode!(Encoding::ASCII_8BIT)
      self.proxy_record["receive-data-length-#{raw_receive_count}"] = databits.unpack("C*").length
      self.proxy_record["receive-data-count"] = raw_receive_count + 1

      write_request(proxy_record,proxy_record_index)

      next_raw_receive_count

      parser_is_finshished = thin_request_parse(data)

      if parser_is_finshished
        p "Commiting Request"
        commit_proxy_record
      end

      return parser_is_finshished
    end
  end
end

require 'sinatra/base'

class Site < Sinatra::Base
  set :root, Proc.new { File.join(File.dirname(__FILE__),'site' )}
  set :public_folder, Proc.new { File.join(File.dirname(__FILE__),'..', "public") }
  before '*' do
    @title = "Site"
  end
	def passthrough_device
    host = "api.staging.fotozap.com"
    store_request(replay = false)
    
    uri = env['REQUEST_URI'] # has a / on the front
    forward_call = "#{env['rack.url_scheme']}://#{host}#{uri}"
    puts "forward call: #{forward_call}"
    p forward_call 
   begin
    Excon.get(forward_call)
   rescue Exception
ret = $!.backtrace
end
end
  get '/iris' do
    erb(:main)
  end
  get '/*' do
	passthrough_device
  end


  def store_request(replayable = true)
  begin

    thin_request = request.env['thin.request'] #  hack
    #debugger

    record = thin_request.proxy_record
    record_index = thin_request.proxy_record_index

    record_index['deviceSerial_bin'] = params['deviceSerial']
    record_index['qrcodes_bin']      = params['qrcodes']
    record_index['replayable_int']   = ( replayable ? 1 : 0)
    attributes = params.dup # take whatever sinatra parses
    attributes.delete('file') # favor raw post data
    attributes.delete('splat') # * glob
    attributes.delete('captures') # * glob 

    attributes['original-request-scheme']         = env['rack.url_scheme']
    attributes['raw-request-uri']  = env['REQUEST_URI'] # usefull for replay
    attributes['requested?'] = 0 if replayable

    attributes[TRAFFIC_COMPLETE] = Time.now.to_ms # changing value  to now
    attributes[TRAFFIC_COMPLETE+"-human"] = Time.now.to_s # changing value  to now


    record.merge!(attributes)
    write_request(record,record_index)
        
    # 
    # oh spagetti
    # 
    thin_request.start_proxy_record # for keep-alive
    ret = %%<?xml version="1.0" encoding="UTF-8"?>
<methodResponse>
    <params>
        <param>
            <value>Image successfully uploaded to Nasrudin's Donkey</value>
        </param>
    </params>
</methodResponse>%
   rescue Exception
     p $!
     p $!.backtrace
     ret = 422 ## error
   end
    ret
  end

  post "/*" do
    puts "--Sintra- Complete Request arrived #{params}"
    content_type "application/xml", :charset => 'utf-8'
    store_request
  end
  
end



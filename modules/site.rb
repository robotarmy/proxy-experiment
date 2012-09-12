# encoding: UTF-8

require 'riak'
require 'yajl'
require 'uri'
require 'debugger'
require "base64"

$client = Riak::Client.new(:http_backend => :Excon)

def write_request(record,record_index) 
  # include the index in the object
  #
  record.merge!(record_index)
  bucket = $client.bucket('requests')
  object = bucket.get_or_new(record['key'])
  object.raw_data = str = Yajl::Encoder.encode(record)
  object.content_type = 'application/json'
  object.indexes = record_index
  object.store
end

TRAFFIC_COMPLETE='traffic-completed-at'

require 'thin'
module Thin
  class Connection
    alias :thin_connection_post_init :post_init
    def post_init(*args)
      p '--before thin_connection_post_init'
      @raw_receive_count  = 0
      #
      # CREATED_PHASE
      #
      # starts out with TRAFFIC_COMPLETE -1
      #
      @record = {
        'key' => $client.stamp.next,
        TRAFFIC_COMPLETE => -1,
      }
      p @record
      #
      # index gets timestamp and remote_ip
      @record_index = {
        'created-at_int' => Time.now.to_i.to_s,
        'remote-address_bin' => remote_address.to_s
      }
      #
      #
      
      @remote_ip =  remote_address
      p @remote_ip + "connected"
      p args
      write_request(@record,@record_index)

      retval = thin_connection_post_init(*args)

      # @request has been created
      @request.proxy_record = @record
      @request.proxy_record_index = @record_index
      
      p '--after thin_connection_post_init'
      return  retval
    end

    alias :thin_connection_receive_data :receive_data
    def receive_data(*args)
      p '--before thin_connection_receive_data'
      @record["receive-data-#{@raw_receive_count}"] = args.first # data
      @record["receive-data-count"] = @raw_receive_count + 1

      write_request(@record,@record_index)

      @raw_receive_count = @raw_receive_count + 1

      p remote_address
      p args

      retval = thin_connection_receive_data(*args)
      p '--after thin_connection_receive_data'
      return  retval
    end

    alias :thin_connection_unbind :unbind
    def unbind(*args)

      @record['connection-closed-at'] = Time.now.to_i

      write_request(@record,@record_index)
      

      p '--before thin_connection_unbind'
      p @remote_ip + "- unbound connection"
      p args
      retval = thin_connection_unbind(*args)
      p '--after thin_connection_unbind'
      return  retval
    end

  end
end

module Thin
  class Request
    attr_accessor :proxy_record,:proxy_record_index
    alias :thin_request_parse :parse
    def parse(*args)
      p '+++before thin_request_parse'
      p args
      @env['thin.request'] = self
      p @env
      retval = thin_request_parse(*args)
      p '+++after thin_request_parse'
      return retval
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
  get '/' do
    erb(:main)
  end

  post "/*" do
    begin
    p params
    # request.body when wrapped in Rack::Lint needs 'read'
    #
   
    p thin_request = request.env['thin.request'] #  hack
    p raw_post = thin_request.body.string
    #debugger

    record = thin_request.proxy_record
    record_index = thin_request.proxy_record_index

    record_index['deviceSerial_bin'] = params['deviceSerial']
    record_index['qrcodes_bin']      = params['qrcodes']
    record_index['request-complete_int']      = 1

    attributes = params.dup # take whatever sinatra parses
    attributes.delete('file') # favor raw post data
    attributes.delete('splat') # * glob
    attributes.delete('captures') # * glob 

    attributes['original-request-scheme']         = env['rack.url_scheme']
    attributes['raw-request-uri']  = env['REQUEST_URI'] # usefull for replay
    attributes['complete-post-body-base64'] = Base64.encode64(raw_post)  # useful for replay
    attributes['requested?'] = 0   # has this REQUEST been forwarded?

    attributes[TRAFFIC_COMPLETE] = Time.now.to_i # changing value  to now
    attributes[TRAFFIC_COMPLETE+"-human"] = Time.now.to_s # changing value  to now


    record.merge!(attributes)
    write_request(record,record_index)

    ret = "Nasrudin was riding on his donkey..."
   rescue
     p $!
     p $!.backtrace
     ret = 422 ## error
   end
    ret
  end
  
end



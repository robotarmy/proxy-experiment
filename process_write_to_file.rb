# encoding: UTF-8

require 'riak'
require 'yajl'
require 'uri'
require 'debugger'
require "base64"

$client = Riak::Client.new(:http_backend => :Excon)


def proccess_request_record(key,hash, &block) 
  receive_data_count = hash['receive-data-count']
  if receive_data_count >=1
    header = Base64.decode64(hash["receive-data-0_base64"])
    # stream request over block
    if block_given?
      block.call( header )
      1.upto(receive_data_count-1) do |index|
        block.call( Base64.decode64(hash["receive-data-#{index}_base64"]))
      end
    end
  end
end


results = $client.get_index('requests','request-complete_int','1')
p results
results.each do | key |
  p key
  p = Yajl::Parser.new
  record = p.parse( $client['requests'][key].raw_data.encode!(Encoding::ASCII_8BIT) )

  File.open(key+'.request',"w+b") do |doc|
    proccess_request_record(key,record) do | request_stream_entry|
      doc << request_stream_entry
    end
  end
end


# encoding: UTF-8

require 'riak'
require 'yajl'
require 'uri'
require 'debugger'
require "base64"

def delete_actual_host_from_request_path(path) 
    
     first_line = path
     actual_host_start = first_line.index("/")

    # index into string relative to after first matching /
    #
     actual_host_end   = first_line[actual_host_start+1..-1].index("/") + actual_host_start 
     actual_host = first_line[actual_host_start+1..actual_host_end]

    # 
    # remove the actual_host
    #
     first_line[actual_host_start..actual_host_end] = "" # remove [/XXXXX]/ from /XXXXX/
    actual_host 
end


def proccess_request_record(key,hash, &block) 
  receive_data_count = hash['receive-data-count']
  if receive_data_count >=1
    header = Base64.decode64(hash["receive-data-0_base64"])
     first_line_end = header.index("\r\n")
     request_path = header[0...first_line_end] # ... is inclusive range
     actual_host = delete_actual_host_from_request_path(request_path)

    puts " ACTUAL HOST : "+  actual_host

    # rewrite original header to have the new request_path
    header[0...first_line_end] = request_path


    # stream request over block
    if block_given?
      block.call( header )
      1.upto(receive_data_count-1) do |index|
        block.call( Base64.decode64(hash["receive-data-#{index}_base64"]))
      end
    end
  end
end


$client = Riak::Client.new(:http_backend => :Excon)
results = $client.get_index('requests','request-complete_int','1')
p results
results.each do | key |
  p key
  p = Yajl::Parser.new
  record = p.parse( $client['requests'][key].raw_data )

  File.open(key+'.request',"w+b") do |doc|
    proccess_request_record(key,record) do | request_stream_entry|
      doc << request_stream_entry
    end
  end
end


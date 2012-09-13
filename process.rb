# encoding: UTF-8

require 'riak'
require 'yajl'
require 'uri'
require 'debugger'
require "base64"

$client = Riak::Client.new(:http_backend => :Excon)
results = $client.get_index('requests','request-complete_int','1')
p results
results.each do | key |
  p key
  p = Yajl::Parser.new
  hash = p.parse( $client['requests'][key].raw_data )
  p hash.keys
  p hash['traffic-completed-at-human']
  receive_data_count = hash['receive-data-count']
  
  File.open(key+'.request',"w+b") do |doc|
    0.upto(receive_data_count-1) do |index|
      doc << Base64.decode64(hash["receive-data-#{index}_base64"])
    end
  end
end

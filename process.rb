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
  p hash['connection-closed-at']
end

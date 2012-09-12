require 'riak'
require 'yajl'
require 'uri'
require 'debugger'
require "base64"

$client = Riak::Client.new(:http_backend => :Excon)
result = $client.get_index('requests','request-complete_int','1')
p result

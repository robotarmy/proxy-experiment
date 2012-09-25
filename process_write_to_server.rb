# encoding: UTF-8
#
# # ssl 
# https://www.braintreepayments.com/braintrust/sslsocket-verify_mode-doesnt-verify?
#
require 'riak'
require 'yajl'
require 'uri'
require 'debugger'
require "base64"
require_relative "./spike/filestore"
$client = Riak::Client.new(:http_backend => :Excon)


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
end


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
    
     block.call(true,actual_host)

    puts " ACTUAL HOST : "+  actual_host

    # rewrite original header to have the new request_path
    header[0...first_line_end] = request_path


    # stream request over block
    if block_given?
      block.call(false,header )
      1.upto(receive_data_count-1) do |index|
        block.call( false,Base64.decode64(hash["receive-data-#{index}_base64"]))
      end
    end
  end
end

require 'socket'      # Sockets are in standard library
require 'openssl'

# https://www.braintreepayments.com/braintrust/sslsocket-verify_mode-doesnt-verify?
def verify_ssl_certificate(preverify_ok, ssl_context)
  if preverify_ok != true || ssl_context.error != 0
    err_msg = "SSL Verification failed -- Preverify: #{preverify_ok}, Error: #{ssl_context.error_string} (#{ssl_context.error})"
    puts "Verify Failed - if this was a real server - I would care"
    #raise OpenSSL::SSL::SSLError.new(err_msg)
  end
  true
end

def setup_socket(hostname,port)

socket = TCPSocket.new(hostname, port)

ssl_context = OpenSSL::SSL::SSLContext.new()
ssl_context.verify_mode = OpenSSL::SSL::VERIFY_PEER
ssl_context.verify_callback = proc do |preverify_ok, ssl_context|
  verify_ssl_certificate(preverify_ok, ssl_context)
end
ssl_context.ca_file = File.join(File.dirname(__FILE__),"ssl" ,"cacert.pem")

ssl_socket = OpenSSL::SSL::SSLSocket.new(socket, ssl_context)
ssl_socket.sync_close = true
ssl_socket.connect

ssl_socket

end

results = $client.get_index('requests','request-complete_int','1')
p results
results.each do | key |
  p key
  p = Yajl::Parser.new
  record = p.parse( $client['requests'][key].raw_data )

  secure =nil
  socket =nil

  proccess_request_record(key,record) do | setup,request_stream_entry|

    if setup
      hostname,port = request_stream_entry.split(":")
      port = "443" unless port
      p 'opening...',hostname,port
      secure,socket = setup_socket(hostname,port)
    else
      secure.print request_stream_entry
    end

  end
  socket.close_write if socket.respond_to? :close_write
  response = StringIO.new(''.encode!(Encoding::ASCII_8BIT))
  response << secure.gets
  p response.string
  record['replay-response'] = response.string
  
  write_request(record)
  unless response.string.length > 0
    puts "socket should have  something in it"
  end

  socket.close if socket
end


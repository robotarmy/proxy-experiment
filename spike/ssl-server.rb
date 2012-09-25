require 'socket'
require 'openssl'
require 'thread'

server  = TCPServer.new(443)
context = OpenSSL::SSL::SSLContext.new

context.cert = OpenSSL::X509::Certificate.new(File.open(File.join(File.dirname(__FILE__),'../ssl/server.crt')))
context.key  = OpenSSL::PKey::RSA.new(File.open(File.join(File.dirname(__FILE__),'../ssl/server.key')))

secure = OpenSSL::SSL::SSLServer.new(server, context)

puts 'Listening securely on port 443...'

loop do
  Thread.new(secure.accept) do |conn|
    begin
      while request = conn.gets
        $stdout.puts '=> ' + request
        response = "You said: #{request}"
        $stdout.puts '<= ' + response
        conn.puts response
      end
    rescue Exception

      $stderr.puts "Error::  #{$!}"
    end
  end
end

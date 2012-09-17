require 'stringio'
x1 ="X-FAKE-HEADER1: " + "8" * 100
x2 ="X-FAKE-HEADER2: " + "9" * 5000
x3 ="X-FAKE-HEADER3: " + "7" * 2000
x4 ="X-FAKE-HEADER4: " + "6" * 10
fake_headers = [
"POST /api.staging.fotozap.com/ssl/rest/upload/jpeg/campaign/100/barcodes/0905161616?pass=db8f9ec8313e0c0e6deac53abc82f54241f30833&user=c1%40s.pct.re&deviceSerial=5a5414b6582db628ac731e65ecf6ad95747c95904 HTTP/1.1", 
"User-Agent: curl/7.21.4 (universal-apple-darwin11.0) libcurl/7.21.4 OpenSSL/0.9.8r zlib/1.2.5", 
"Host: oo:3000", 
x1,
x2,
x3,
x4,
"Accept: */*", 
"Content-Length: 67619",
#"Expect: 100-continue", 
"Content-Type: multipart/form-data; boundary=----------------------------1b18e8aa8815"
]

fake_body = ("1" * 67619) + "\r\n"



fake_head = fake_headers.join("\r\n") + "\r\n\r\n"
fake_head.encode!(Encoding::ASCII_8BIT)
require 'socket'      # Sockets are in standard library

hostname = 'localhost'
port = 9000

def assert(condition, msg)
   if !condition
     puts "ASSERT-FAIL "+ msg
   end
end

s = TCPSocket.open(hostname, port)
Socket.tcp(hostname,port) do | s |
s.print(fake_head)
s.print(fake_body)
s.close_write

line = StringIO.new(''.encode!(Encoding::ASCII_8BIT))
line << s.gets
p line.string
assert(line.string.length > 0, "socket should have  something in it")
end



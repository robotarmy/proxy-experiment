require './module_loader'

map '/' do
  run Site.new
end
map '/cgi-bin' do
  app = lambda do |env|
    body = "I saw it at /cgi-bin"
    [200, {"Content-Type" => "text/plain", "Content-Length" => body.length.to_s}, [body]]
  end
  run app
end


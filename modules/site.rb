# encoding: UTF-8
require 'sinatra/base'
require 'riak'




$client = Riak::Client.new(:http_backend => :Excon)



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
    p raw_post = request.body.string
    p env = request.env

    p device_bucket = params['deviceSerial']
    p device_request = params['qrcodes']
    bucket = $client.bucket(device_bucket)
    object = bucket.get_or_new(device_request)
    attributes = params.dup # take whatever sinatra parses
    attributes.delete('file') # favor raw post data
    attributes.delete('splat') # * glob
    attributes.delete('captures') # * glob 
    attributes['raw-request-uri']  = env['REQUEST_URI'] # usefull for replay
    attributes['post-body'] = raw_post  # useful for replay
    attributes['requested?'] = 0   # has this REQUEST been forwarded?
    p attributes
    object.data = attributes
    object.content_type = 'application/json'
    object.store
 
    ret = "Nasrudin was riding on his donkey..."
   rescue
     p $!
     ret = 422 ## error
   end
    ret
  end
  
end



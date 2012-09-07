# encoding: UTF-8
require 'sinatra/base'
require 'riak'
require 'yajl'
require 'uri'
require "base64"

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
    p okey =params['qrcodes'] 
    p device_request_key = Base64.encode64(okey).chomp # drop newline from base64 encodeing scheme
    bucket = $client.bucket(device_bucket)
    object = bucket.get_or_new(device_request_key)
    attributes = params.dup # take whatever sinatra parses
    attributes.delete('file') # favor raw post data
    attributes.delete('splat') # * glob
    attributes.delete('captures') # * glob 
    attributes['original-request-remote-addr']      = env['REMOTE_ADDR']
    attributes['original-request-scheme']         = env['rack.url_scheme']
    attributes['unencoded-key']    = okey
    attributes['raw-request-uri']  = env['REQUEST_URI'] # usefull for replay
    attributes['post-body'] = Base64.encode64(raw_post)  # useful for replay
    attributes['requested?'] = 0   # has this REQUEST been forwarded?
    #p attributes
    object.key = device_request_key
    object.raw_data = str = Yajl::Encoder.encode(attributes)
    #p str
    object.content_type = 'application/json'
    p object
    object.store
 
    ret = "Nasrudin was riding on his donkey..."
   rescue
     p $!
     ret = 422 ## error
   end
    ret
  end
  
end



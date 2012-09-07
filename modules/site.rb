# encoding: UTF-8
require 'sinatra/base'
class Iris

end
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
    p params
    p request.env['rack.input'].string
    p request.env
    "Nasrudin was riding on his donkey..."
  end
  
end



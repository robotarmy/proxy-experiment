require 'rack/test'
require_relative '../module_loader'

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
end


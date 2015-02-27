require 'json'
require 'sinatra'

get '/' do
  redirect '/index.html'
end

get '/:name/' do
    content_type "application/json"
    return {"test" => "#{params['name']}"}.to_json
end
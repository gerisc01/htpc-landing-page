require 'json'
require 'sinatra'

# Load config file
config_file = File.new("public/config.json").read
# Parse the config file
config = JSON.parse config_file
# Holds the plugin class that is currently intialized
plugin = nil

get '/' do
  redirect '/index.html'
end

get '/:name/init' do
    require "./public/plugins/#{params["name"]}/config"
    plugin = YouTube.new
end

get '/:name/destroy' do
    plugin = YouTube.destroy
end

get '/:name/getResourceUrl' do
    content_type "application/json"
    url = plugin.send(:getResourceUrl, params["id"])
    return {"url" => url}.to_json
end

# http.htpc.dev/youtube/get_subs?limit=&page=&token=&count=
# {"splat"=>[], "captures"=>["youtube", "getChannels"], "name"=>"youtube", "method"=>"getChannels"}
#{"nextPageToken"=>"CAAQAA", "pageInfo"=>{"totalResults"=>20, "resultsPerPage"=>0}, "items"=>[]}
get '/:name/:method' do
    content_type "application/json"
    methodParams = params.select{|params| !["splat", "captures"].include?(params)}
    puts "Sending to method with params... #{params.inspect}"
    return plugin.send(:"#{params["method"]}",methodParams)
end
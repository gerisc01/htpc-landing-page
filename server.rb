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

# http.htpc.dev/youtube/get_subs?id=...&limit=...&offset=...
get '/:name/:method' do
    content_type "application/json"
    return plugin.send(:"#{params['method']}","1","2","3")
end
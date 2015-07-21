require 'json'
require 'sinatra'
require 'sinatra-websocket'

# Load config file
config_file = File.new("public/config.json").read
# Parse the config file
config = JSON.parse config_file
# Holds the plugin class that is currently intialized
plugin = nil

set :server, 'thin'
set :sockets, []

get '/' do
  redirect '/index.html'
end

get '/:name/init' do
    require "./public/plugins/#{params["name"]}/config"
    title = config["tiles"][params["name"]]["title"]
    obj = Object.const_get(title.gsub(" ",""))
    plugin = obj::Navigation.new
end

get '/nowplaying/ws' do
    request.websocket do |ws|
      ws.onopen do
        ws.send("websocket opened")
        settings.sockets << ws
      end
      ws.onmessage do |msg|
        puts msg
        EM.next_tick { settings.sockets.each{|s| s.send(msg) } }
      end
      ws.onclose do
        warn("websocket closed")
        settings.sockets.delete(ws)
      end
    end
end

get '/:name/nowplaying/:method' do
    puts "Sending to method with params... #{params.inspect}"
end

get '/:name/getResourceUrl' do
    content_type "application/json"
    url = plugin.send(:getResourceUrl, params["id"])
    return {"url" => url}.to_json
end

get '/:name/:method' do
    content_type "application/json"
    methodParams = params.select{|params| !["splat", "captures"].include?(params)}
    puts "Sending to method with params... #{params.inspect}"
    return plugin.send(:"#{params["method"]}",methodParams)
end

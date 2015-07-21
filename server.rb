require 'json'
require 'sinatra'
require 'sinatra-websocket'

# Load config file
config_file = File.new("public/config.json").read
# Parse the config file
config = JSON.parse config_file
# Holds the plugin class that is currently intialized
plugin = nil
navigation = nil
nowplaying = nil

set :server, 'thin'
set :sockets, []

get '/' do
  redirect '/index.html'
end

get '/nowplaying/init' do
    nowplaying = plugin::NowPlaying.new
end

get '/:name/init' do
    require "./public/plugins/#{params["name"]}/config"
    title = config["tiles"][params["name"]]["title"]
    plugin = Object.const_get(title.gsub(" ",""))
    navigation = plugin::Navigation.new
    nowplaying = plugin::NowPlaying.new # Added for the time being to make life easier
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

post '/nowplaying/controls/:control?/?:state?' do
    if params["state"] != nil
        nowplaying.send(:"#{params['control']}",params["state"])
    else
        nowplaying.send(:"#{params['control']}")
    end
end

get '/nowplaying/:method' do
    content_type "application/json"
    {}
    return nowplaying.send(:"#{params["method"]}") if ["queue","info"].include? params["method"]
end

get '/:name/getResourceUrl' do
    content_type "application/json"
    url = navigation.send(:getResourceUrl, params["id"])
    return {"url" => url}.to_json
end

get '/:name/:method' do
    content_type "application/json"
    methodParams = params.select{|params| !["splat", "captures"].include?(params)}
    puts "Sending to method with params... #{params.inspect}"
    return navigation.send(:"#{params["method"]}",methodParams)
end

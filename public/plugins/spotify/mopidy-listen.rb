require 'websocket-client-simple'

ws = WebSocket::Client::Simple.connect 'http://127.0.0.1:6680/mopidy/ws'

ws.on :message do |msg|
  puts msg.data
end

ws.on :open do
  ws.send 'hello!!!'
end

ws.on :close do |e|
  p e
  exit 1
end

ws.on :error do |e|
  p e
end
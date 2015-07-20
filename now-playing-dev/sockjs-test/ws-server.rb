#!/usr/bin/env ruby
# encoding: utf-8

require "rack"
require "rack/sockjs"
require "eventmachine"

# Your custom app.
class MyHelloWorld
  def call(env)
    body = "This is the app, not SockJS."
    headers = {
      "Content-Type" => "text/plain; charset=UTF-8",
      "Content-Length" => body.bytesize.to_s
    }

    [200, headers, [body]]
  end
end


app = Rack::Builder.new do
  # Run one SockJS app on /echo.
  use SockJS, "/echo" do |connection|
    connection.subscribe do |session, message|
      session.send(message)
    end
  end

  # ... and the other one on /close.
  use SockJS, "/close" do |connection|
    connection.session_open do |session|
      session.close(3000, "Go away!")
    end
  end

  # This app will run on other URLs than /echo and /close,
  # as these has already been assigned to SockJS.
  run MyHelloWorld.new
end


EM.run do
  thin = Rack::Handler.get("thin")
  thin.run(app.to_app, Port: 8081)
end

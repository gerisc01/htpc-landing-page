module Spotify
    class NowPlaying
        def initialize()
            
        end

        def setup_webhook(params)
            @now_playing = WebSocket::Client::Simple.connect 'ws://127.0.0.1:4567/nowplaying/ws'
            @mopidy_ws = WebSocket::Client::Simple.connect 'http://127.0.0.1:6680/mopidy/ws'

            @mopidy_ws.on :message do |msg|
              puts parse_event(msg.data)
              puts @now_playing.open?
              @now_playing.send(msg.data)
            end

            @mopidy_ws.on :open do
              puts "Starting Listening to Mopidy on 'http://127.0.0.1:6680/mopidy/ws'"
            end

            @mopidy_ws.on :close do |e|
              puts "Stopping Listening to Mopidy on 'http://127.0.0.1:6680/mopidy/ws'"
            end

            @mopidy_ws.on :error do |e|
              p e
            end
        end

        def destroy_webhook(params)
            @mopidy_ws.close
            @now_playing.close
        end

        def parse_event(event_json)
            # Current possible events
            # tracklist_changed
            # playback_state_changed
            # track_playback_started/track_playback_ended
            json = JSON.parse(event_json)
            event = json["event"]
        end

        def get_queue(params)
            
        end

        def get_information(params)
            # Get Album Art
            # Get Artist Name
            # Get Track Name

        end

        def get_play_state(params)
            
        end
    end
end
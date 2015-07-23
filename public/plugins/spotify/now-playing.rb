module Spotify
    class NowPlaying
        def initialize()
            params = {"jsonrpc" => "2.0","id" => 1,"method" => "core.tracklist.set_consume","params" => [true]}
            RestClient.post("http://localhost:6680/mopidy/rpc",params.to_json,:content_type => :json)
        end

        def play()
            params = {"jsonrpc" => "2.0","id" => 1,"method" => "core.playback.play","params" => []}
            RestClient.post("http://localhost:6680/mopidy/rpc",params.to_json,:content_type => :json)
        end

        def pause()
            params = {"jsonrpc" => "2.0","id" => 1,"method" => "core.playback.pause","params" => []}
            RestClient.post("http://localhost:6680/mopidy/rpc",params.to_json,:content_type => :json)
        end

        def next()
            params = {"jsonrpc" => "2.0","id" => 1,"method" => "core.playback.next","params" => []}
            RestClient.post("http://localhost:6680/mopidy/rpc",params.to_json,:content_type => :json)
        end

        def previous()
            params = {"jsonrpc" => "2.0","id" => 1,"method" => "core.playback.previous","params" => []}
            RestClient.post("http://localhost:6680/mopidy/rpc",params.to_json,:content_type => :json)
        end

        def shuffle(state)
            # state is not currently needed
        end

        def repeat(state)
            # state is not currently needed
        end

        def queue()
            results = {}
            results["history"] = get_history(5)
            results["current"] = get_current
            results["future"] = get_future(20)

            return results.to_json
        end

        def info()
            # Get Album Art
            # Get Artist Name
            # Get Track Name
        end

        def get_history(limit)
            params = {"jsonrpc" => "2.0","id" => 1,"method" => "core.history.get_history","params" => []}
            resp = RestClient.post("http://localhost:6680/mopidy/rpc",params.to_json,:content_type => :json)

            json = JSON.parse(resp)
            uris = []
            for result in json["result"]
                if uris.size >= limit
                    break
                end
                uris.push(result[1]["uri"])
            end

            params = {"jsonrpc" => "2.0","id" => 1,"method" => "core.library.lookup","params" => [nil,uris]}
            resp = RestClient.post("http://localhost:6680/mopidy/rpc",params.to_json,:content_type => :json)

            json = JSON.parse(resp)
            history = []
            for uri in uris
                result = json["result"][uri]
                track = {"uri" => result[0]["uri"], "name" => result[0]["name"]}

                artists = []
                for artist in result[0]["artists"]
                    artists.push(artist["name"])
                end
                track["artists"] = artists.join(",")

                history.push(track)
            end

            return history
        end

        def get_future(limit)
            params = {"jsonrpc" => "2.0","id" => 1,"method" => "core.tracklist.get_tracks","params" => []}
            resp = RestClient.post("http://localhost:6680/mopidy/rpc",params.to_json,:content_type => :json)

            json = JSON.parse(resp)
            future = []
            for result in json["result"]
                if future.size > limit
                    return future.drop(1)
                end
                track = {"uri" => result["uri"], "name" => result["name"]}

                artists = []
                for artist in result["artists"]
                    artists.push(artist["name"])
                end
                track["artists"] = artists.join(",")

                future.push(track)
            end

            return future.drop(1)
        end

        def get_current()
            params = {"jsonrpc" => "2.0","id" => 1,"method" => "core.playback.get_current_track","params" => []}
            resp = RestClient.post("http://localhost:6680/mopidy/rpc",params.to_json,:content_type => :json)

            json = JSON.parse(resp)
            track = {
                "uri" => json["result"]["uri"], 
                "name" => json["result"]["name"],
                "album" => json["result"]["album"]["name"],
                "album_uri" => json["result"]["album"]["uri"]
            }

            artists = []
            for artist in json["result"]["artists"]
                artists.push(artist["name"])
            end
            track["artists"] = artists.join(",")

            return track
        end
    end
end
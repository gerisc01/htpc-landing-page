module Spotify
    class Navigation
        def initialize()
            require 'restclient'
            require 'base64'
            require 'json'
            require 'websocket-client-simple'
            require_relative 'now-playing.rb'
            @user_id = "scott.gerike"
            @client_id = "6a4ec190bc1b405099a8256f17c456d1"
            @client_secret = "e9f5adc49029473f93add702787b676f"
            @refresh_token = "AQCrqtaGwPNV2OM1had6fR6ezjBnxXAbasFDFvVX6xAtuV53YJ777KLENEoGA4gAe_Mu2O_XSdKQEuIUHDXU9BRfryuIXEhvidcULZC2xrR1c27WiWkEF6LShTzie2NJFEw"
            @artists = File.read("/Users/scottgerike/dev/htpc-landing-page/public/plugins/spotify/artists.txt").split("\n")
            # if defined? @token_expire != nil && Time.now > @token_expire
            #     @access_token = auth()
            #     puts @access_token
            # end

            begin
                startListening()
            rescue Exception => e
                raise e
            end
        end

        def auth()
            # Initialize the Authorization resource
            resource = RestClient::Resource.new("https://accounts.spotify.com", :user => @client_id, :password => @client_secret)
            begin
                resp = resource["api/token"].post "grant_type=refresh_token&refresh_token=" + @refresh_token
            rescue RestClient::Exception => ex
                puts ex.inspect
            end
            jsonResp = JSON.parse(resp)
            @access_token = jsonResp['access_token']
            @token_expire = Time.now + jsonResp['expires_in'].to_i

            return @access_token
        end

        def destroy(params)
            if defined? @ws
                stopListening()
            end
        end

        # Currently works on every number up to 172
        def getPageSize(count, maxPageSize)
            idealPageCounts = [4,6,8,9,12,15,16]
            if count <= maxPageSize
                return maxPageSize
            else
                # Figure out how many pages are needed
                for j in 2..100
                    if count <= (maxPageSize * j) - (2*j-2)
                        # j is the amount of pages needed
                        # real_count is the count including navigation arrows
                        real_count = count + (2*j-2)
                        for size in idealPageCounts.reverse
                            if real_count - (j-1) * size > 3
                                return size
                            end
                        end
                        raise StandardError, "FAILURE: CAN'T RETRIEVE PAGE SIZE"
                    end
                end
            end
        end

        def stopListening()
            puts "Stopped Listening to Mopidy on 'http://127.0.0.1:6680/mopidy/ws'"
            @mopidy_ws.close
        end

        def startListening()
            now_playing = WebSocket::Client::Simple.connect 'ws://127.0.0.1:4567/nowplaying/ws'
            @mopidy_ws = WebSocket::Client::Simple.connect 'http://127.0.0.1:6680/mopidy/ws'

            for i in 1..10
                if now_playing.open?
                    now_playing.send("Started Listening to Spotify/Mopidy")
                    break
                end
                puts "Waiting to open"
                sleep(1)
            end

            @mopidy_ws.on :message do |msg|
                #puts a.inspect
                #puts now_playing.inspect
                now_playing.send(msg.data)
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

        def parse_event(event_json)
            # Current possible events
            # tracklist_changed
            # playback_state_changed
            # track_playback_started/track_playback_ended
            json = JSON.parse(event_json)
            event = json["event"]
            msg = {}
            if event == "playback_state_changed"
                msg["type"] = "play-pause"
                msg["new_state"] = json["new_state"]
            elsif event == "tracklist_changed"
                msg["type"] = "queue"
            end
        end

        def getMyPlaylists(params)
            #== Params
            # *limit*: the limit for the amount of tiles that will be on the page
            # offset: the offset so that the results are started at the correct page
            # count: the total count of the resource
            # page: 1,2,3,4,...

            req_params = {}
            req_params["limit"] = params["limit"]
            req_params["offset"] = params["offset"] if params["offset"] != nil

            begin
                resp = RestClient.get("https://api.spotify.com/v1/users/#{@user_id}/playlists",:params => req_params, :authorization => "Bearer #{@access_token}")
            rescue RestClient::Exception => ex
                puts ex.inspect
            end
            json = JSON.parse(resp)
            items = json["items"]

            # + If the the total count wasn't passed, find it from the response. 
            # + Find the ideal pageSize using the getPageSize method. 
            # + pageSize != limit, reset the limit to pageSize and call the method again
            if params["count"].to_s.empty?
                params["count"] = json["total"]
                params["page"] = "1"
                pageSize = getPageSize(params["count"].to_i, params["limit"].to_i)
                if params["count"].to_i > pageSize
                    params["limit"] = (pageSize - 1).to_s
                    params["last_page"] = (((params["count"].to_i - 1 - (pageSize-1)*2)/(pageSize-2)) + 3).to_s
                else
                    params["limit"] = pageSize.to_s
                    params["last_page"] = "1"
                end
                params["offset"] = 0
                items = items.slice(0,params["limit"].to_i)
            end

            # Find the total amount of pages possible based on count and limit. Also
            # caulculate offset
            last_page = params["last_page"].to_i
            offset = (params["limit"].to_i * (params["page"].to_i - 1)) + (1 * ((params["page"].to_i-1)/1000)).ceil

            # Configure the data
            # + If first page, put in data for nextPage tile
            # + If last page, put in data for prevPage tile
            # + If middle page, put in data for both tiles
            data = []
            if params["page"] != "1"
                if params["page"].to_i - 1 == 1 && params["last_page"] != "2"
                    limit = params['limit'].to_i + 1
                elsif params["page"] == params["last_page"] && params["page"] != 2
                    limit = params['limit'].to_i - 1
                else
                    limit = params['limit']
                end
                prev_page = {}
                prev_page["title"] = "Previous"
                prev_page["id"] = ""
                prev_page["icon"] = "/prevPage.gif"
                prev_page["layout"] = "/spotify/getMyPlaylists?limit=#{limit}&count=#{params['count']}&page=#{params['page'].to_i-1}"
                prev_page["layout"] += "&offset=#{params['offset'].to_i-limit}&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
                data.push(prev_page) 
            end
            for playlist in items
                sub_data = {}
                sub_data["title"] = playlist["name"]
                sub_data["id"] = playlist["uri"]
                sub_data["layout"] = "playlists-list"
                #get proper image url
                images = playlist["images"]
                if images.length == 1
                    sub_data["icon"] = images[0]["url"]
                elsif images.length == 0
                    sub_data["icon"] = ""
                else
                    sub_data["icon"] = images[1]["url"]
                end
                data.push(sub_data)
            end
            if params["page"] != last_page.to_s
                if params["page"].to_i + 1 == last_page && params["page"] != "1"
                    limit = params['limit'].to_i + 1
                elsif params["page"] == "1"
                    limit = params['limit'].to_i - 1
                else
                    limit = params['limit']
                end
                next_page = {}
                next_page["title"] = "Next"
                next_page["id"] = ""
                next_page["icon"] = "/nextPage.gif"
                next_page["layout"] = "/spotify/getMyPlaylists?limit=#{limit}&count=#{params['count']}&page=#{params['page'].to_i+1}" 
                next_page["layout"] += "&offset=#{params['offset'].to_i+params['limit'].to_i}&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
                data.push(next_page)
            end

            return data.to_json
        end

        def getTracks(params)
            #== Params
            # *id*: the id of the resource that tracks will come from
            # *limit*: the limit for the amount of tiles that will be on the page
            # offset: the offset so that the results are started at the correct page
            # count: the total count of the resource
            # page: 1,2,3,4,...

            req_params = {}
            req_params["limit"] = params["limit"]
            req_params["offset"] = params["offset"] if params["offset"] != nil

            album_image = nil
            if match = params["id"].match(/spotify:user:(.*?):playlist:(.*?)\z/i)
                user, id = match.captures
                begin
                    resp = RestClient.get("https://api.spotify.com/v1/users/#{user}/playlists/#{id}/tracks", :params => req_params, :authorization => "Bearer #{@access_token}")
                rescue RestClient::Exception => ex
                    puts ex.inspect
                end
            elsif match = params["id"].match(/spotify:album:(.*?)\z/i)
                id = match.captures.first
                begin
                    resp = RestClient.get("https://api.spotify.com/v1/albums/#{id}/tracks", :params => req_params, :authorization => "Bearer #{@access_token}")
                rescue RestClient::Exception => ex
                    puts ex.inspect
                end

                # Also get images
                begin
                    imgResp = RestClient.get("https://api.spotify.com/v1/albums/#{id}", :authorization => "Bearer #{@access_token}")
                rescue RestClient::Exception => ex
                    puts ex.inspect
                end
                imgJson = JSON.parse(imgResp)
                album_image = imgJson["images"]
            end
            json = JSON.parse(resp)
            items = json["items"]

            # + If the the total count wasn't passed, find it from the response. 
            # + Find the ideal pageSize using the getPageSize method. 
            # + pageSize != limit, reset the limit to pageSize and call the method again
            if params["count"].to_s.empty?
                params["count"] = json["total"]
                params["page"] = "1"
                pageSize = getPageSize(params["count"].to_i, params["limit"].to_i)
                if params["count"].to_i > pageSize
                    params["limit"] = (pageSize - 1).to_s
                    params["last_page"] = (((params["count"].to_i - 1 - (pageSize-1)*2)/(pageSize-2)) + 3).to_s
                else
                    params["limit"] = pageSize.to_s
                    params["last_page"] = "1"
                end
                params["offset"] = 0
                items = items.slice(0,params["limit"].to_i)
            end

            puts params.inspect

            # Find the total amount of pages possible based on count and limit. Also
            # caulculate offset
            last_page = params["last_page"].to_i
            offset = (params["limit"].to_i * (params["page"].to_i - 1)) + (1 * ((params["page"].to_i-1)/1000)).ceil

            # Configure the data
            # + If first page, put in data for nextPage tile
            # + If last page, put in data for prevPage tile
            # + If middle page, put in data for both tiles
            data = []
            if params["page"] != "1"
                if params["page"].to_i - 1 == 1 && params["last_page"] != "2"
                    limit = params['limit'].to_i + 1
                elsif params["page"] == params["last_page"] && params["page"] != "2"
                    limit = params['limit'].to_i - 1
                else
                    limit = params['limit'].to_i
                end
                prev_page = {}
                prev_page["title"] = "Previous"
                prev_page["id"] = ""
                prev_page["icon"] = "/prevPage.gif"
                prev_page["layout"] = "/spotify/getTracks?limit=#{limit}&count=#{params['count']}&page=#{params['page'].to_i-1}&id=#{params['id']}"
                prev_page["layout"] += "&offset=#{params['offset'].to_i-limit}&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
                data.push(prev_page)
            end

            for item in items
                if item["track"] != nil
                    song = item["track"]
                    images = song["album"]["images"]
                else
                    song = item
                    images = album_image
                end
                sub_data = {}
                sub_data["title"] = song["name"]
                sub_data["id"] = song["uri"]
                if images.length == 1
                    sub_data["icon"] = images[0]["url"]
                elsif images.length == 0
                    sub_data["icon"] = ""
                else
                    sub_data["icon"] = images[1]["url"]
                end
                # id_array.push(song["uri"])
                sub_data["layout"] = ""
                data.push(sub_data)
            end

            if params["page"] != last_page.to_s
                if params["page"].to_i + 1 == last_page && params["page"] != "1"
                    limit = params['limit'].to_i + 1
                elsif params["page"] == "1" && params["last_page"] != "2"
                    limit = params['limit'].to_i - 1
                else
                    limit = params['limit'].to_i
                end
                next_page = {}
                next_page["title"] = "Next"
                next_page["id"] = ""
                next_page["icon"] = "/nextPage.gif"
                next_page["layout"] = "/spotify/getTracks?limit=#{limit}&count=#{params['count']}&page=#{params['page'].to_i+1}&id=#{params['id']}" 
                next_page["layout"] += "&offset=#{params['offset'].to_i+params['limit'].to_i}&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
                data.push(next_page)
            end

            return data.to_json
        end

        def getMyTracks(params)
            #== Params
            # *limit*: the limit for the amount of tiles that will be on the page
            # offset: the offset so that the results are started at the correct page
            # count: the total count of the resource
            # page: 1,2,3,4,...

            req_params = {}
            req_params["limit"] = params["limit"]
            req_params["offset"] = params["offset"] if params["offset"] != nil

            begin
                resp = RestClient.get("https://api.spotify.com/v1/me/tracks", :params => req_params, :authorization => "Bearer #{@access_token}")
            rescue RestClient::Exception => ex
                puts ex.inspect
            end
            json = JSON.parse(resp)
            items = json["items"]

            # + If the the total count wasn't passed, find it from the response. 
            # + Find the ideal pageSize using the getPageSize method. 
            # + pageSize != limit, reset the limit to pageSize and call the method again
            if params["count"].to_s.empty?
                params["count"] = json["total"]
                params["page"] = "1"
                pageSize = getPageSize(params["count"].to_i, params["limit"].to_i)
                if params["count"].to_i > pageSize
                    params["limit"] = (pageSize - 1).to_s
                    params["last_page"] = (((params["count"].to_i - 1 - (pageSize-1)*2)/(pageSize-2)) + 3).to_s
                else
                    params["limit"] = pageSize.to_s
                    params["last_page"] = "1"
                end
                params["offset"] = 0
                items = items.slice(0,params["limit"].to_i)
            end

            puts params.inspect

            # Find the total amount of pages possible based on count and limit. Also
            # caulculate offset
            last_page = params["last_page"].to_i
            offset = (params["limit"].to_i * (params["page"].to_i - 1)) + (1 * ((params["page"].to_i-1)/1000)).ceil

            # Configure the data
            # + If first page, put in data for nextPage tile
            # + If last page, put in data for prevPage tile
            # + If middle page, put in data for both tiles
            data = []
            if params["page"] != "1"
                if params["page"].to_i - 1 == 1 && params["last_page"] != "2"
                    limit = params['limit'].to_i + 1
                elsif params["page"] == params["last_page"] && params["page"] != "2"
                    limit = params['limit'].to_i - 1
                else
                    limit = params['limit'].to_i
                end
                prev_page = {}
                prev_page["title"] = "Previous"
                prev_page["id"] = ""
                prev_page["icon"] = "/prevPage.gif"
                prev_page["layout"] = "/spotify/getMyTracks?limit=#{limit}&count=#{params['count']}&page=#{params['page'].to_i-1}&id=#{params['id']}"
                prev_page["layout"] += "&offset=#{params['offset'].to_i-limit}&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
                data.push(prev_page)
            end

            for item in items
                if item["track"] != nil
                    song = item["track"]
                    images = song["album"]["images"]
                else
                    song = item
                    images = album_image
                end
                sub_data = {}
                sub_data["title"] = song["name"]
                sub_data["id"] = song["uri"]
                if images.length == 1
                    sub_data["icon"] = images[0]["url"]
                elsif images.length == 0
                    sub_data["icon"] = ""
                else
                    sub_data["icon"] = images[1]["url"]
                end
                # id_array.push(song["uri"])
                sub_data["layout"] = ""
                data.push(sub_data)
            end

            if params["page"] != last_page.to_s
                if params["page"].to_i + 1 == last_page && params["page"] != "1"
                    limit = params['limit'].to_i + 1
                elsif params["page"] == "1" && params["last_page"] != "2"
                    limit = params['limit'].to_i - 1
                else
                    limit = params['limit'].to_i
                end
                next_page = {}
                next_page["title"] = "Next"
                next_page["id"] = ""
                next_page["icon"] = "/nextPage.gif"
                next_page["layout"] = "/spotify/getMyTracks?limit=#{limit}&count=#{params['count']}&page=#{params['page'].to_i+1}&id=#{params['id']}" 
                next_page["layout"] += "&offset=#{params['offset'].to_i+params['limit'].to_i}&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
                data.push(next_page)
            end

            return data.to_json
        end

        def getFeaturedPlaylists(params)
            #== Params
            # *limit*: the limit for the amount of tiles that will be on the page
            # offset: the offset so that the results are started at the correct page
            # count: the total count of the resource
            # page: 1,2,3,4,...

            req_params = {}
            req_params["limit"] = params["limit"]
            req_params["offset"] = params["offset"] if params["offset"] != nil
            req_params["timestamp"] = DateTime.now.to_s

            begin
                resp = RestClient.get("https://api.spotify.com/v1/browse/featured-playlists",:params => req_params, :authorization => "Bearer #{@access_token}")
            rescue RestClient::Exception => ex
                puts ex.inspect
            end
            json = JSON.parse(resp)
            items = json["playlists"]["items"]

            # + If the the total count wasn't passed, find it from the response. 
            # + Find the ideal pageSize using the getPageSize method. 
            # + pageSize != limit, reset the limit to pageSize and call the method again
            if params["count"].to_s.empty?
                params["count"] = json["playlists"]["total"]
                params["page"] = "1"
                pageSize = getPageSize(params["count"].to_i, params["limit"].to_i)
                if params["count"].to_i > pageSize
                    params["limit"] = (pageSize - 1).to_s
                    params["last_page"] = (((params["count"].to_i - 1 - (pageSize-1)*2)/(pageSize-2)) + 3).to_s
                else
                    params["limit"] = pageSize.to_s
                    params["last_page"] = "1"
                end
                params["offset"] = 0
                items = items.slice(0,params["limit"].to_i)
            end

            # Find the total amount of pages possible based on count and limit. Also
            # caulculate offset
            last_page = params["last_page"].to_i
            offset = (params["limit"].to_i * (params["page"].to_i - 1)) + (1 * ((params["page"].to_i-1)/1000)).ceil

            # Configure the data
            # + If first page, put in data for nextPage tile
            # + If last page, put in data for prevPage tile
            # + If middle page, put in data for both tiles
            data = []
            if params["page"] != "1"
                if params["page"].to_i - 1 == 1 && params["last_page"] != "2"
                    limit = params['limit'].to_i + 1
                elsif params["page"] == params["last_page"] && params["page"] != 2
                    limit = params['limit'].to_i - 1
                else
                    limit = params['limit']
                end
                prev_page = {}
                prev_page["title"] = "Previous"
                prev_page["id"] = ""
                prev_page["icon"] = "/prevPage.gif"
                prev_page["layout"] = "/spotify/getFeaturedPlaylists?limit=#{limit}&count=#{params['count']}&page=#{params['page'].to_i-1}"
                prev_page["layout"] += "&offset=#{params['offset'].to_i-limit}&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
                data.push(prev_page) 
            end
            for playlist in items
                sub_data = {}
                sub_data["title"] = playlist["name"]
                sub_data["id"] = playlist["uri"]
                sub_data["layout"] = "featured-list"
                #get proper image url
                images = playlist["images"]
                if images.length == 1
                    sub_data["icon"] = images[0]["url"]
                elsif images.length == 0
                    sub_data["icon"] = ""
                else
                    sub_data["icon"] = images[1]["url"]
                end
                data.push(sub_data)
            end
            if params["page"] != last_page.to_s
                if params["page"].to_i + 1 == last_page && params["page"] != "1"
                    limit = params['limit'].to_i + 1
                elsif params["page"] == "1"
                    limit = params['limit'].to_i - 1
                else
                    limit = params['limit']
                end
                next_page = {}
                next_page["title"] = "Next"
                next_page["id"] = ""
                next_page["icon"] = "/nextPage.gif"
                next_page["layout"] = "/spotify/getFeaturedPlaylists?limit=#{limit}&count=#{params['count']}&page=#{params['page'].to_i+1}"
                next_page["layout"] += "&offset=#{params['offset'].to_i+params['limit'].to_i}&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
                data.push(next_page)
            end

            return data.to_json
        end

        def getCategories(params)
            #== Params
            # *limit*: the limit for the amount of tiles that will be on the page
            # offset: the offset so that the results are started at the correct page
            # count: the total count of the resource
            # page: 1,2,3,4,...

            req_params = {}
            req_params["limit"] = params["limit"]
            req_params["offset"] = params["offset"] if params["offset"] != nil

            begin
                resp = RestClient.get("https://api.spotify.com/v1/browse/categories",:params => req_params, :authorization => "Bearer #{@access_token}")
            rescue RestClient::Exception => ex
                puts ex.inspect
            end
            json = JSON.parse(resp)
            items = json["categories"]["items"]

            # + If the the total count wasn't passed, find it from the response. 
            # + Find the ideal pageSize using the getPageSize method. 
            # + pageSize != limit, reset the limit to pageSize and call the method again
            if params["count"].to_s.empty?
                params["count"] = json["categories"]["total"]
                params["page"] = "1"
                pageSize = getPageSize(params["count"].to_i, params["limit"].to_i)
                if params["count"].to_i > pageSize
                    params["limit"] = (pageSize - 1).to_s
                    params["last_page"] = (((params["count"].to_i - 1 - (pageSize-1)*2)/(pageSize-2)) + 3).to_s
                else
                    params["limit"] = pageSize.to_s
                    params["last_page"] = "1"
                end
                params["offset"] = 0
                items = items.slice(0,params["limit"].to_i)
            end

            # Find the total amount of pages possible based on count and limit. Also
            # caulculate offset
            last_page = params["last_page"].to_i
            offset = (params["limit"].to_i * (params["page"].to_i - 1)) + (1 * ((params["page"].to_i-1)/1000)).ceil

            # Configure the data
            # + If first page, put in data for nextPage tile
            # + If last page, put in data for prevPage tile
            # + If middle page, put in data for both tiles
            data = []
            if params["page"] != "1"
                if params["page"].to_i - 1 == 1 && params["last_page"] != "2"
                    limit = params['limit'].to_i + 1
                elsif params["page"] == params["last_page"] && params["page"] != 2
                    limit = params['limit'].to_i - 1
                else
                    limit = params['limit']
                end
                prev_page = {}
                prev_page["title"] = "Previous"
                prev_page["id"] = ""
                prev_page["icon"] = "/prevPage.gif"
                prev_page["layout"] = "/spotify/getCategories?limit=#{limit}&count=#{params['count']}&page=#{params['page'].to_i-1}"
                prev_page["layout"] += "&offset=#{params['offset'].to_i-limit}&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
                data.push(prev_page) 
            end
            for category in items
                sub_data = {}
                sub_data["title"] = category["name"]
                sub_data["id"] = category["id"]
                sub_data["layout"] = "by-category"
                #get proper image url
                images = category["icons"]
                if images.length == 1
                    sub_data["icon"] = images[0]["url"]
                elsif images.length == 0
                    sub_data["icon"] = ""
                else
                    sub_data["icon"] = images[1]["url"]
                end
                data.push(sub_data)
            end
            if params["page"] != last_page.to_s
                if params["page"].to_i + 1 == last_page && params["page"] != "1"
                    limit = params['limit'].to_i + 1
                elsif params["page"] == "1"
                    limit = params['limit'].to_i - 1
                else
                    limit = params['limit']
                end
                next_page = {}
                next_page["title"] = "Next"
                next_page["id"] = ""
                next_page["icon"] = "/nextPage.gif"
                next_page["layout"] = "/spotify/getCategories?limit=#{limit}&count=#{params['count']}&page=#{params['page'].to_i+1}"
                next_page["layout"] += "&offset=#{params['offset'].to_i+params['limit'].to_i}&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
                data.push(next_page)
            end

            return data.to_json
        end

        def getByCategory(params)
            #== Params
            # *id*: the id for the category that was selected
            # *limit*: the limit for the amount of tiles that will be on the page
            # offset: the offset so that the results are started at the correct page
            # count: the total count of the resource
            # page: 1,2,3,4,...

            req_params = {}
            req_params["limit"] = params["limit"]
            req_params["offset"] = params["offset"] if params["offset"] != nil

            begin
                resp = RestClient.get("https://api.spotify.com/v1/browse/categories/#{params['id']}/playlists",:params => req_params, :authorization => "Bearer #{@access_token}")
            rescue RestClient::Exception => ex
                puts ex.inspect
            end
            json = JSON.parse(resp)
            items = json["playlists"]["items"]

            # + If the the total count wasn't passed, find it from the response. 
            # + Find the ideal pageSize using the getPageSize method. 
            # + pageSize != limit, reset the limit to pageSize and call the method again
            if params["count"].to_s.empty?
                params["count"] = json["playlists"]["total"]
                params["page"] = "1"
                pageSize = getPageSize(params["count"].to_i, params["limit"].to_i)
                if params["count"].to_i > pageSize
                    params["limit"] = (pageSize - 1).to_s
                    params["last_page"] = (((params["count"].to_i - 1 - (pageSize-1)*2)/(pageSize-2)) + 3).to_s
                else
                    params["limit"] = pageSize.to_s
                    params["last_page"] = "1"
                end
                params["offset"] = 0
                items = items.slice(0,params["limit"].to_i)
            end

            # Find the total amount of pages possible based on count and limit. Also
            # caulculate offset
            last_page = params["last_page"].to_i
            offset = (params["limit"].to_i * (params["page"].to_i - 1)) + (1 * ((params["page"].to_i-1)/1000)).ceil

            # Configure the data
            # + If first page, put in data for nextPage tile
            # + If last page, put in data for prevPage tile
            # + If middle page, put in data for both tiles
            data = []
            if params["page"] != "1"
                if params["page"].to_i - 1 == 1 && params["last_page"] != "2"
                    limit = params['limit'].to_i + 1
                elsif params["page"] == params["last_page"] && params["page"] != 2
                    limit = params['limit'].to_i - 1
                else
                    limit = params['limit']
                end
                prev_page = {}
                prev_page["title"] = "Previous"
                prev_page["id"] = ""
                prev_page["icon"] = "/prevPage.gif"
                prev_page["layout"] = "/spotify/getByCategory?limit=#{limit}&count=#{params['count']}&page=#{params['page'].to_i-1}"
                prev_page["layout"] += "&offset=#{params['offset'].to_i-limit}&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
                data.push(prev_page) 
            end
            for playlist in items
                sub_data = {}
                sub_data["title"] = playlist["name"]
                sub_data["id"] = playlist["uri"]
                sub_data["layout"] = "category-playlists"
                #get proper image url
                images = playlist["images"]
                if images.length == 1
                    sub_data["icon"] = images[0]["url"]
                elsif images.length == 0
                    sub_data["icon"] = ""
                else
                    sub_data["icon"] = images[1]["url"]
                end
                data.push(sub_data)
            end
            if params["page"] != last_page.to_s
                if params["page"].to_i + 1 == last_page && params["page"] != "1"
                    limit = params['limit'].to_i + 1
                elsif params["page"] == "1"
                    limit = params['limit'].to_i - 1
                else
                    limit = params['limit']
                end
                next_page = {}
                next_page["title"] = "Next"
                next_page["id"] = ""
                next_page["icon"] = "/nextPage.gif"
                next_page["layout"] = "/spotify/getByCategory?limit=#{limit}&count=#{params['count']}&page=#{params['page'].to_i+1}"
                next_page["layout"] += "&offset=#{params['offset'].to_i+params['limit'].to_i}&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
                data.push(next_page)
            end

            return data.to_json
        end

        def getNewReleases(params)
            #== Params
            # *limit*: the limit for the amount of tiles that will be on the page
            # offset: the offset so that the results are started at the correct page
            # count: the total count of the resource
            # page: 1,2,3,4,...

            req_params = {}
            req_params["limit"] = params["limit"]
            req_params["offset"] = params["offset"] if params["offset"] != nil

            begin
                resp = RestClient.get("https://api.spotify.com/v1/browse/new-releases",:params => req_params, :authorization => "Bearer #{@access_token}")
            rescue RestClient::Exception => ex
                puts ex.inspect
            end
            json = JSON.parse(resp)
            items = json["albums"]["items"]

            # + If the the total count wasn't passed, find it from the response. 
            # + Find the ideal pageSize using the getPageSize method. 
            # + pageSize != limit, reset the limit to pageSize and call the method again
            if params["count"].to_s.empty?
                params["count"] = json["albums"]["total"]
                params["page"] = "1"
                pageSize = getPageSize(params["count"].to_i, params["limit"].to_i)
                if params["count"].to_i > pageSize
                    params["limit"] = (pageSize - 1).to_s
                    params["last_page"] = (((params["count"].to_i - 1 - (pageSize-1)*2)/(pageSize-2)) + 3).to_s
                else
                    params["limit"] = pageSize.to_s
                    params["last_page"] = "1"
                end
                params["offset"] = 0
                items = items.slice(0,params["limit"].to_i)
            end

            # Find the total amount of pages possible based on count and limit. Also
            # caulculate offset
            last_page = params["last_page"].to_i
            offset = (params["limit"].to_i * (params["page"].to_i - 1)) + (1 * ((params["page"].to_i-1)/1000)).ceil

            # Configure the data
            # + If first page, put in data for nextPage tile
            # + If last page, put in data for prevPage tile
            # + If middle page, put in data for both tiles
            data = []
            if params["page"] != "1"
                if params["page"].to_i - 1 == 1 && params["last_page"] != "2"
                    limit = params['limit'].to_i + 1
                elsif params["page"] == params["last_page"] && params["page"] != 2
                    limit = params['limit'].to_i - 1
                else
                    limit = params['limit'].to_i
                end
                prev_page = {}
                prev_page["title"] = "Previous"
                prev_page["id"] = ""
                prev_page["icon"] = "/prevPage.gif"
                prev_page["layout"] = "/spotify/getNewReleases?limit=#{limit}&count=#{params['count']}&page=#{params['page'].to_i-1}"
                prev_page["layout"] += "&offset=#{params['offset'].to_i-limit}&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
                data.push(prev_page) 
            end
            for album in items
                sub_data = {}
                sub_data["title"] = album["name"]
                sub_data["id"] = album["uri"]
                sub_data["layout"] = "by-new-release"
                #get proper image url
                images = album["images"]
                if images.length == 1
                    sub_data["icon"] = images[0]["url"]
                elsif images.length == 0
                    sub_data["icon"] = ""
                else
                    sub_data["icon"] = images[1]["url"]
                end
                data.push(sub_data)
            end
            if params["page"] != last_page.to_s
                if params["page"].to_i + 1 == last_page && params["page"] != "1"
                    limit = params['limit'].to_i + 1
                elsif params["page"] == "1"
                    limit = params['limit'].to_i - 1
                else
                    limit = params['limit']
                end
                next_page = {}
                next_page["title"] = "Next"
                next_page["id"] = ""
                next_page["icon"] = "/nextPage.gif"
                next_page["layout"] = "/spotify/getNewReleases?limit=#{limit}&count=#{params['count']}&page=#{params['page'].to_i+1}"
                next_page["layout"] += "&offset=#{params['offset'].to_i+params['limit'].to_i}&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
                data.push(next_page)
            end

            return data.to_json
        end

        def getArtists(params)
            # + If the the total count wasn't passed, find it from the response. 
            # + Find the ideal pageSize using the getPageSize method. 
            # + pageSize != limit, reset the limit to pageSize and call the method again
            if params["count"].to_s.empty?
                params["count"] = @artists.size
                params["page"] = "1"
                pageSize = getPageSize(params["count"].to_i, params["limit"].to_i)
                if params["count"].to_i > pageSize
                    params["limit"] = (pageSize - 1).to_s
                    params["last_page"] = (((params["count"].to_i - 1 - (pageSize-1)*2)/(pageSize-2)) + 3).to_s
                else
                    params["limit"] = pageSize.to_s
                    params["last_page"] = "1"
                end
                params["offset"] = 0
                # items = items.slice(0,params["limit"].to_i)
            end

            # Find the total amount of pages possible based on count and limit. Also
            # caulculate offset
            last_page = params["last_page"].to_i
            offset = (params["limit"].to_i * (params["page"].to_i - 1)) + (1 * ((params["page"].to_i-1)/1000)).ceil

            artist_split = @artists.slice(params["offset"].to_i,params["limit"].to_i)
            artist_ids = []
            for artist in artist_split
                artist_ids.push(artist.split("::")[1])
            end

            req_params = {}
            req_params["ids"] = artist_ids.join(",")

            begin
                resp = RestClient.get("https://api.spotify.com/v1/artists",:params => req_params, :authorization => "Bearer #{@access_token}")
            rescue RestClient::Exception => ex
                puts ex.inspect
            end
            json = JSON.parse(resp)
            artists = json["artists"]

            # Configure the data
            # + If first page, put in data for nextPage tile
            # + If last page, put in data for prevPage tile
            # + If middle page, put in data for both tiles
            data = []
            if params["page"] != "1"
                if params["page"].to_i - 1 == 1 && params["last_page"] != "2"
                    limit = params['limit'].to_i + 1
                elsif params["page"] == params["last_page"] && params["page"] != 2
                    limit = params['limit'].to_i - 1
                else
                    limit = params['limit'].to_i
                end
                prev_page = {}
                prev_page["title"] = "Previous"
                prev_page["id"] = ""
                prev_page["icon"] = "/prevPage.gif"
                prev_page["layout"] = "/spotify/getArtists?limit=#{limit}&count=#{params['count']}&page=#{params['page'].to_i-1}"
                prev_page["layout"] += "&offset=#{params['offset'].to_i-limit}&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
                data.push(prev_page) 
            end
            for artist in artists
                sub_data = {}
                sub_data["title"] = artist["name"]
                sub_data["id"] = artist["uri"]
                sub_data["layout"] = "get-artists"
                #get proper image url
                images = artist["images"]
                if images.length == 1
                    sub_data["icon"] = images[0]["url"]
                elsif images.length == 0
                    sub_data["icon"] = ""
                else
                    sub_data["icon"] = images[1]["url"]
                end
                data.push(sub_data)
            end
            if params["page"] != last_page.to_s
                if params["page"].to_i + 1 == last_page && params["page"] != "1"
                    limit = params['limit'].to_i + 1
                elsif params["page"] == "1"
                    limit = params['limit'].to_i - 1
                else
                    limit = params['limit']
                end
                next_page = {}
                next_page["title"] = "Next"
                next_page["id"] = ""
                next_page["icon"] = "/nextPage.gif"
                next_page["layout"] = "/spotify/getArtists?limit=#{limit}&count=#{params['count']}&page=#{params['page'].to_i+1}"
                next_page["layout"] += "&offset=#{params['offset'].to_i+params['limit'].to_i}&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
                data.push(next_page)
            end

            return data.to_json
        end

        def getArtistAlbums(params)
            #== Params
            # *id*: the id for the category that was selected
            # *limit*: the limit for the amount of tiles that will be on the page
            # offset: the offset so that the results are started at the correct page
            # count: the total count of the resource
            # page: 1,2,3,4,...

            req_params = {}
            req_params["limit"] = params["limit"]
            req_params["offset"] = params["offset"] if params["offset"] != nil
            req_params["album_type"] = "album,single"
            req_params["market"] = "US"

            uri = params["id"]
            id = uri.split(":")[2]
            begin
                resp = RestClient.get("https://api.spotify.com/v1/artists/#{id}/albums",:params => req_params, :authorization => "Bearer #{@access_token}")
            rescue RestClient::Exception => ex
                puts ex.inspect
            end
            json = JSON.parse(resp)
            albums = json["items"]

            # + If the the total count wasn't passed, find it from the response. 
            # + Find the ideal pageSize using the getPageSize method. 
            # + pageSize != limit, reset the limit to pageSize and call the method again
            if params["count"].to_s.empty?
                params["count"] = json["total"]
                params["page"] = "1"
                pageSize = getPageSize(params["count"].to_i, params["limit"].to_i)
                if params["count"].to_i > pageSize
                    params["limit"] = (pageSize - 1).to_s
                    params["last_page"] = (((params["count"].to_i - 1 - (pageSize-1)*2)/(pageSize-2)) + 3).to_s
                else
                    params["limit"] = pageSize.to_s
                    params["last_page"] = "1"
                end
                params["offset"] = 0
                albums = albums.slice(0,params["limit"].to_i)
            end

            # Find the total amount of pages possible based on count and limit. Also
            # caulculate offset
            last_page = params["last_page"].to_i
            offset = (params["limit"].to_i * (params["page"].to_i - 1)) + (1 * ((params["page"].to_i-1)/1000)).ceil

            # Configure the data
            # + If first page, put in data for nextPage tile
            # + If last page, put in data for prevPage tile
            # + If middle page, put in data for both tiles
            data = []
            if params["page"] != "1"
                if params["page"].to_i - 1 == 1 && params["last_page"] != "2"
                    limit = params['limit'].to_i + 1
                elsif params["page"] == params["last_page"] && params["page"] != 2
                    limit = params['limit'].to_i - 1
                else
                    limit = params['limit'].to_i
                end
                prev_page = {}
                prev_page["title"] = "Previous"
                prev_page["id"] = ""
                prev_page["icon"] = "/prevPage.gif"
                prev_page["layout"] = "/spotify/getArtistAlbums?limit=#{limit}&count=#{params['count']}&page=#{params['page'].to_i-1}"
                prev_page["layout"] += "&offset=#{params['offset'].to_i-limit}&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
                data.push(prev_page) 
            end
            for album in albums
                sub_data = {}
                sub_data["title"] = album["name"]
                sub_data["id"] = album["uri"]
                sub_data["layout"] = "get-artist-albums"
                #get proper image url
                images = album["images"]
                if images.length == 1
                    sub_data["icon"] = images[0]["url"]
                elsif images.length == 0
                    sub_data["icon"] = ""
                else
                    sub_data["icon"] = images[1]["url"]
                end
                data.push(sub_data)
            end
            if params["page"] != last_page.to_s
                if params["page"].to_i + 1 == last_page && params["page"] != "1"
                    limit = params['limit'].to_i + 1
                elsif params["page"] == "1"
                    limit = params['limit'].to_i - 1
                else
                    limit = params['limit']
                end
                next_page = {}
                next_page["title"] = "Next"
                next_page["id"] = ""
                next_page["icon"] = "/nextPage.gif"
                next_page["layout"] = "/spotify/getArtistAlbums?limit=#{limit}&count=#{params['count']}&page=#{params['page'].to_i+1}"
                next_page["layout"] += "&offset=#{params['offset'].to_i+params['limit'].to_i}&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
                data.push(next_page)
            end

            return data.to_json
        end

        def getTopCharts(params)
            params["id"] = "toplists"
            getByCategory(params)
        end
    end
end
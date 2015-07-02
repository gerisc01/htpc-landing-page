class Spotify
    def initialize()
        require 'restclient'
        require 'base64'
        require 'json'
        @user_id = "scott.gerike"
        @client_id = "6a4ec190bc1b405099a8256f17c456d1"
        @client_secret = "e9f5adc49029473f93add702787b676f"
        @refresh_token = "AQCwzMZCBORr_UHVWxmjFDEtvZzCTQvhA4QogyHe5dGcV5mh7HyMLdBnfafcUWMd84TJuB4RdvsXYiUC7lOKpv4cOH1kgrgjptUyg9w0GbpchBMoNkrqvT86wd1rB030w2I"
        if defined? @token_expire != nil && Time.now > @token_expire
            @access_token = auth()
            puts @access_token
        end

        begin
            #startMopidy()
            #puts @mopidy_pid
            #sleep(2)
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
        if defined? @mopidy_pid
            endMopidy()
        end
    end

    # Currently works on every number up to 172
    def getPageSize(count, pageSize)
        idealPageCounts = [6,8,9,12,15,16]
        currentCount = count
        page = 1
        while (currentCount > 0)
            lostTiles = (page == 1 || currentCount < pageSize - 1) ? 1 : 2
            if (currentCount - (pageSize-lostTiles)) <= 0 || count > 500
                finalPageSize = currentCount + 1
                if finalPageSize <  5
                    newPageCount = idealPageCounts[idealPageCounts.index(pageSize)-1]
                    raise StandardError, "FAILURE: CAN'T RETRIEVE PAGE SIZE" if newPageCount > pageSize
                    return getPageSize(count, newPageCount)
                end
                return pageSize
            end
            currentCount -= (pageSize - lostTiles)
            page += 1
        end
    end

    def startMopidy()
        @mopidy_pid = fork do
            exec "mopidy"
        end
    end

    def endMopidy()
        Process.kill "TERM", @mopidy_pid
    end

    def startListening()
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
            params["limit"] = pageSize - 1 # Figure out why subtracting by 1?
            params["offset"] = 0
            params["last_page"] = ((params["count"].to_i - (pageSize-1)*2)/(pageSize-2)) + 3;
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

        rpcJSON = {"jsonrpc" => "2.0", "id" => 1, "method" => "core.library.browse", "params" => [params["id"]]}

        begin
            resp = RestClient.post("http://localhost:6680/mopidy/rpc",rpcJSON.to_json)
        rescue RestClient::Exception => ex
            puts ex.inspect
        end

        json = JSON.parse(resp)
        songs = json["result"]

        ########################################################################
        # Always returns everything, so limit and offset are handled differenty
        # Will always slice the item list down to the proper size before doing
        # future exploration calls
        ########################################################################
        if !params["count"].to_s.empty?
            songs = songs.slice(params["offset"].to_i,params["limit"].to_i)
        end

        # + If the the total count wasn't passed, find it from the response. 
        # + Find the ideal pageSize using the getPageSize method. 
        # + pageSize != limit, reset the limit to pageSize and call the method again
        if params["count"].to_s.empty?
            params["count"] = songs.size
            params["page"] = "1"
            pageSize = getPageSize(params["count"].to_i, params["limit"].to_i)
            params["limit"] = pageSize - 1 # Figure out why subtracting by 1?
            params["offset"] = 0
            params["last_page"] = (((params["count"].to_i - (pageSize-1)*2)/(pageSize-2)) + 3).to_s;
            songs = songs.slice(0,params["limit"].to_i)
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
            prev_page["layout"] = "/spotify/getByPlaylist?limit=#{limit}&count=#{params['count']}&page=#{params['page'].to_i-1}&id=#{params['id']}"
            prev_page["layout"] += "&offset=#{params['offset'].to_i-limit}&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
            data.push(prev_page)
        end

        # Build up ids to call mopidy for spotify album art for each song
        id_array = []
        for song in songs
            sub_data = {}
            sub_data["title"] = song["name"]
            sub_data["id"] = song["uri"]
            id_array.push(song["uri"])
            sub_data["layout"] = ""
            data.push(sub_data)
        end

        # Current not working, calling directly from spotify unless this starts to work again
        # imagesJSON = {"jsonrpc" => "2.0", "id" => 1, "method" => "core.library.get_images", "params" => [id_array]}
        # begin
        #     resp = RestClient.post("http://localhost:6680/mopidy/rpc",imagesJSON.to_json)
        # rescue RestClient::Exception => ex
        #     puts ex.inspect
        # end
        # puts resp
        # imgResp = JSON.parse(resp)
        # imgHash = imgResp["result"]


        # Temp solution
        for i in 0...id_array.size
            id_array[i] = id_array[i].split(":")[2]
        end
        begin
            resp = RestClient.get("https://api.spotify.com/v1/tracks/?ids=#{id_array.join(',')}", :authorization => "Bearer #{@access_token}")
        rescue RestClient::Exception => ex
            puts ex.inspect
        end
        json = JSON.parse(resp)
        tracks = json["tracks"]
        imgHash = {}
        for track in tracks
            imgHash[track["uri"]] = track["album"]["images"]
        end

        for i in 0...data.size
            sub_data = data[i]
            if sub_data["id"] != ""
                images = imgHash[sub_data["id"]]
                if images.length == 1
                    sub_data["icon"] = images[0]["url"]
                elsif images.length == 0
                    sub_data["icon"] = ""
                else
                    sub_data["icon"] = images[1]["url"]
                end
            end
            data[i] = sub_data
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
            next_page["layout"] = "/spotify/getByPlaylist?limit=#{limit}&count=#{params['count']}&page=#{params['page'].to_i+1}&id=#{params['id']}" 
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
            params["limit"] = pageSize - 1 # Figure out why subtracting by 1?
            params["offset"] = 0
            params["last_page"] = ((params["count"].to_i - (pageSize-1)*2)/(pageSize-2)) + 3;
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
            params["limit"] = pageSize - 1 # Figure out why subtracting by 1?
            params["offset"] = 0
            params["last_page"] = ((params["count"].to_i - (pageSize-1)*2)/(pageSize-2)) + 3;
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
            params["limit"] = pageSize - 1 # Figure out why subtracting by 1?
            params["offset"] = 0
            params["last_page"] = ((params["count"].to_i - (pageSize-1)*2)/(pageSize-2)) + 3;
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

    def getArtists()

    end

    def getAlbums()

    end
end
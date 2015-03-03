class YouTube
    def initialize()
    require 'google/api_client'
    @client_id = "884949577715-rubgj6qt7cn8arba2idi6qc6d8da7am0.apps.googleusercontent.com"
    @client_secret = "ratpOOny0oD9-oW8hUVnreiM"
    @refresh_token = "1/flE86o4HxqrGehz7mIMdDNKyxwoM38jAWD8RJu1rCvgMEudVrK5jSpoR30zcRFq6"
    @client = auth()
    @youtube_discovered_api = @client.discovered_api("youtube", "v3")
    end

    def auth()
    # Initialize the Google Calendar API client
        client = Google::APIClient.new({:authorization => :oauth_2})

        client.authorization = Signet::OAuth2::Client.new(
          :token_credential_uri => 'https://accounts.google.com/o/oauth2/token',
          :client_id => @client_id,
          :client_secret => @client_secret,
          :refresh_token => @refresh_token
        )
        client.authorization.fetch_access_token!
        return client
    end

    def getPageSize(count, pageSize)
        idealPageCounts = [6,8,9,12,15,16]
        currentCount = count
        page = 1
        while (currentCount > 0)
            lostTiles = (page == 1 || currentCount < pageSize - 1) ? 1 : 2
            if (currentCount - (pageSize-lostTiles)) < 0
                finalPageSize = currentCount + 1
                if finalPageSize <  5
                    newPageCount = idealPageCounts[idealPageCounts.index(pageSize)-1]
                    raise StandardError, "FAILURE: CAN'T RETRIEVE PAGE SIZE" if newPageCount > pageSize
                    return getPageSize(count, newPageCount)
                end
                puts "Amount of Pages: #{page}"
                puts "Final Page: #{finalPageSize}"
                return pageSize
            end
            currentCount -= (pageSize - lostTiles)
            page += 1
        end
    end

    def getChannels(params)
        #== Params
        # *limit*: the limit for the whole page, including back and forward buttons
        # token: token used to get the next page
        # count: the total count of the resource
        # pageType: first, middle, last

        # Setting up the parameters for the API Call
        youtube_params = {
            :part => "snippet",
            :mine => true,
            :fields => "items/snippet,nextPageToken,prevPageToken,pageInfo",
            :maxResults => params["limit"].to_i,
            :order => "alphabetical"
        }
        # If a token was included, add it to the params for the API call
        youtube_params[:pageToken] = params["token"] if !params["token"].to_s.empty?

        # Execute the API call
        channel = @client.execute!(
            :api_method => @youtube_discovered_api.subscriptions.list,
            :parameters => youtube_params
        )
        # Retrieve the results
        resp = JSON.parse(channel.response.body)

        # + If the the total count wasn't passed, find it from the response. 
        # + Find the ideal pageSize using the getPageSize method. 
        # + pageSize != limit, reset the limit to pageSize and call the method again
        if params["count"].to_s.empty?
            params["count"] = resp["pageInfo"]["totalResults"]
            pageSize = getPageSize(params["count"].to_i, params["limit"].to_i)
            if pageSize != params["limit"].to_i
                params["limit"] = pageSize
                getChannels(params)
            end
        end

        # Configure the data
        # + If first page, put in data for nextPage tile
        # + If last page, put in data for prevPage tile
        # + If middle page, put in data for both tiles
        data = []
        for sub in resp["items"]
            sub_data = {}
            sub_data["title"] = sub["snippet"]["title"]
            sub_data["id"] = sub["snippet"]["resourceId"]["channelId"]
            sub_data["icon"] = sub["snippet"]["thumbnails"]["high"]["url"]
            sub_data["layout"] = "subscribers-list"
            data.push(sub_data)
        end

        return data.to_json
    end

    def getPlaylist(id, limit, offset)

    end

    def getByChannel(id, limit, offset)

    end

    def getByPlaylist(id, limit, offset)

    end

    def getWatchLater(id, limit, offset)

    end

    def getPopular(id, limit, offset)

    end
end
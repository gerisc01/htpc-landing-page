class YouTube
    def initialize()
        require 'google/api_client'
        @client_id = "884949577715-rubgj6qt7cn8arba2idi6qc6d8da7am0.apps.googleusercontent.com"
        @client_secret = "ratpOOny0oD9-oW8hUVnreiM"
        @refresh_token = "1/flE86o4HxqrGehz7mIMdDNKyxwoM38jAWD8RJu1rCvgMEudVrK5jSpoR30zcRFq6"
        @client = auth()
        @youtube_discovered_api = @client.discovered_api("youtube", "v3")
        findStandardPlaylistIds
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

    def destroy()

    end

    def findStandardPlaylistIds()
        youtube_params = {
            :part => "contentDetails",
            :mine => true,
            :fields => "items/contentDetails,pageInfo"
        }

        # Execute the API call
        channel = @client.execute!(
            :api_method => @youtube_discovered_api.channels.list,
            :parameters => youtube_params
        )
        # Retrieve the results
        resp = JSON.parse(channel.response.body)
        @watchlater = resp["items"][0]["contentDetails"]["relatedPlaylists"]["watchLater"]
        @watchhistory = resp["items"][0]["contentDetails"]["relatedPlaylists"]["watchHistory"]
        @likes = resp["items"][0]["contentDetails"]["relatedPlaylists"]["likes"]
    end

    def getResourceUrl(id)
        return "https://www.youtube.com/watch?v=" + id
    end

    # Currently works on every number up to 172
    def getPageSize(count, pageSize)
        idealPageCounts = [6,8,9,12,15,16]
        currentCount = count
        page = 1
        while (currentCount > 0)
            lostTiles = (page == 1 || currentCount < pageSize - 1) ? 1 : 2
            if (currentCount - (pageSize-lostTiles)) <= 0
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

    def getChannels(params)
        #== Params
        # *limit*: the limit for the amount of tiles that will be on the page
        # token: token used to get the next page
        # count: the total count of the resource
        # page: 1,2,3,4,...

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
        youtube_params[:maxResults] = 0 if params["count"].to_s.empty? # don't return any item info when just returning the count

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
            params["page"] = "1"
            pageSize = getPageSize(params["count"].to_i, params["limit"].to_i)
            params["limit"] = pageSize - 1
            params["last_page"] = ((params["count"].to_i - (pageSize-1)*2)/(pageSize-2)) + 3;
            return getChannels(params)
        end

        # Find the total amount of pages possible based on count and limit
        last_page = params["last_page"].to_i

        # Configure the data
        # + If first page, put in data for nextPage tile
        # + If last page, put in data for prevPage tile
        # + If middle page, put in data for both tiles
        data = []
        if params["page"] != "1"
            if params["page"].to_i - 1 == 1 && params["last_page"] != "2"
                limit = params['limit'].to_i + 1
            elsif params["page"].to_i == params["last_page"]
                limit = params['limit'].to_i - 1
            else
                limit = params['limit']
            end
            prev_page = {}
            prev_page["title"] = "Previous"
            prev_page["id"] = ""
            prev_page["icon"] = "/prevPage.gif"
            prev_page["layout"] = "/youtube/getChannels?limit=#{limit}&count=#{params['count']}&page=#{params['page'].to_i-1}&token=#{resp['prevPageToken']}"
            prev_page["layout"] += "&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
            data.push(prev_page) 
        end
        for sub in resp["items"]
            sub_data = {}
            sub_data["title"] = sub["snippet"]["title"]
            sub_data["id"] = sub["snippet"]["resourceId"]["channelId"]
            sub_data["icon"] = sub["snippet"]["thumbnails"]["high"]["url"]
            sub_data["layout"] = "subscribers-list"
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
            next_page["layout"] = "/youtube/getChannels?limit=#{limit}&count=#{params['count']}&page=#{params['page'].to_i+1}&token=#{resp['nextPageToken']}" 
            next_page["layout"] += "&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
            data.push(next_page)
        end

        return data.to_json
    end

    def getPlaylists(params)
        #== Params
        # *limit*: the limit for the amount of tiles that will be on the page
        # token: token used to get the next page
        # count: the total count of the resource
        # page: 1,2,3,4,...

        # Setting up the parameters for the API Call
        youtube_params = {
            :part => "snippet",
            :mine => true,
            :fields => "items(id,snippet),nextPageToken,prevPageToken,pageInfo",
            :maxResults => params["limit"].to_i
        }
        # If a token was included, add it to the params for the API call
        youtube_params[:pageToken] = params["token"] if !params["token"].to_s.empty?
        youtube_params[:maxResults] = 0 if params["count"].to_s.empty? # don't return any item info when just returning the count

        # Execute the API call
        channel = @client.execute!(
            :api_method => @youtube_discovered_api.playlists.list,
            :parameters => youtube_params
        )
        # Retrieve the results
        resp = JSON.parse(channel.response.body)

        # + If the the total count wasn't passed, find it from the response. 
        # + Find the ideal pageSize using the getPageSize method. 
        # + pageSize != limit, reset the limit to pageSize and call the method again
        if params["count"].to_s.empty?
            params["count"] = resp["pageInfo"]["totalResults"]
            params["page"] = "1"
            pageSize = getPageSize(params["count"].to_i, params["limit"].to_i)
            params["limit"] = pageSize - 1
            params["last_page"] = ((params["count"].to_i - (pageSize-1)*2)/(pageSize-2)) + 3;
            return getPlaylists(params)
        end

        # Find the total amount of pages possible based on count and limit
        last_page = params["last_page"].to_i

        # Configure the data
        # + If first page, put in data for nextPage tile
        # + If last page, put in data for prevPage tile
        # + If middle page, put in data for both tiles
        data = []
        if params["page"] != "1"
            if params["page"].to_i - 1 == 1 && params["last_page"] != "2"
                limit = params['limit'].to_i + 1
            elsif params["page"].to_i == params["last_page"]
                limit = params['limit'].to_i - 1
            else
                limit = params['limit']
            end
            prev_page = {}
            prev_page["title"] = "Previous"
            prev_page["id"] = ""
            prev_page["icon"] = "/prevPage.gif"
            prev_page["layout"] = "/youtube/getChannels?limit=#{limit}&count=#{params['count']}&page=#{params['page'].to_i-1}&token=#{resp['prevPageToken']}"
            prev_page["layout"] += "&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
            data.push(prev_page) 
        end
        for sub in resp["items"]
            sub_data = {}
            sub_data["title"] = sub["snippet"]["title"]
            sub_data["id"] = sub["id"]
            sub_data["icon"] = sub["snippet"]["thumbnails"]["high"]["url"]
            sub_data["layout"] = "playlists-list"
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
            next_page["layout"] = "/youtube/getChannels?limit=#{limit}&count=#{params['count']}&page=#{params['page'].to_i+1}&token=#{resp['nextPageToken']}" 
            next_page["layout"] += "&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
            data.push(next_page)
        end

        return data.to_json
    end

    def getByChannel(params)
        #== Params
        # *id*: the id of the channel that you want to return videos from
        # *limit*: the limit for the amount of tiles that will be on the page
        # token: token used to get the next page
        # count: the total count of the resource
        # page: 1,2,3,4,...

        # Setting up the parameters for the API Call
        youtube_params = {
            :part => "snippet",
            :channelId => params["id"],
            :fields => "items(id,snippet),nextPageToken,prevPageToken,pageInfo",
            :maxResults => params["limit"].to_i,
            :type => "video",
            :order => "date"
        }
        # If a token was included, add it to the params for the API call
        youtube_params[:pageToken] = params["token"] if !params["token"].to_s.empty?
        youtube_params[:maxResults] = 0 if params["count"].to_s.empty? # don't return any item info when just returning the count

        # Execute the API call
        channel = @client.execute!(
            :api_method => @youtube_discovered_api.search.list,
            :parameters => youtube_params
        )
        # Retrieve the results
        resp = JSON.parse(channel.response.body)

        # + If the the total count wasn't passed, find it from the response. 
        # + Find the ideal pageSize using the getPageSize method. 
        # + pageSize != limit, reset the limit to pageSize and call the method again
        # + Find the total amount of pages possible based on count and limit
        if params["count"].to_s.empty?
            params["count"] = resp["pageInfo"]["totalResults"]
            params["page"] = "1"
            pageSize = getPageSize(params["count"].to_i, params["limit"].to_i)
            params["limit"] = pageSize - 1
            params["last_page"] = ((params["count"].to_i - (pageSize-1)*2)/(pageSize-2)) + 3;
            return getByChannel(params)
        end

        last_page = params["last_page"].to_i

        # Configure the data
        # + If first page, put in data for nextPage tile
        # + If last page, put in data for prevPage tile
        # + If middle page, put in data for both tiles
        data = []
        if params["page"] != "1"
            if params["page"].to_i - 1 == 1 && params["last_page"] != "2"
                limit = params['limit'].to_i + 1
            elsif params["page"].to_i == params["last_page"]
                limit = params['limit'].to_i - 1
            else
                limit = params['limit']
            end
            prev_page = {}
            prev_page["title"] = "Previous"
            prev_page["id"] = ""
            prev_page["icon"] = "/prevPage.gif"
            prev_page["layout"] = "/youtube/getByChannel?&limit=#{limit}&id=#{params["id"]}&count=#{params['count']}&page=#{params['page'].to_i-1}&token=#{resp['prevPageToken']}"
            prev_page["layout"] += "&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
            data.push(prev_page) 
        end
        for sub in resp["items"]
            sub_data = {}
            sub_data["title"] = sub["snippet"]["title"]
            sub_data["id"] = sub["id"]["videoId"]
            sub_data["icon"] = sub["snippet"]["thumbnails"]["high"]["url"]
            sub_data["layout"] = ""
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
            next_page["layout"] = "/youtube/getByChannel?limit=#{limit}&id=#{params["id"]}&count=#{params['count']}&page=#{params['page'].to_i+1}&token=#{resp['nextPageToken']}" 
            next_page["layout"] += "&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
            data.push(next_page)
        end

        return data.to_json
    end

    def getByPlaylist(params)
        #== Params
        # *id*: the id of the channel that you want to return videos from
        # *limit*: the limit for the amount of tiles that will be on the page
        # token: token used to get the next page
        # count: the total count of the resource
        # page: 1,2,3,4,...

        # Setting up the parameters for the API Call
        youtube_params = {
            :part => "snippet",
            :playlistId => params["id"],
            :fields => "items/snippet,nextPageToken,prevPageToken,pageInfo",
            :maxResults => params["limit"].to_i
        }
        # If a token was included, add it to the params for the API call
        youtube_params[:pageToken] = params["token"] if !params["token"].to_s.empty?
        youtube_params[:maxResults] = 0 if params["count"].to_s.empty? # don't return any item info when just returning the count

        # Execute the API call
        channel = @client.execute!(
            :api_method => @youtube_discovered_api.playlist_items.list,
            :parameters => youtube_params
        )
        # Retrieve the results
        resp = JSON.parse(channel.response.body)

        # + If the the total count wasn't passed, find it from the response. 
        # + Find the ideal pageSize using the getPageSize method. 
        # + pageSize != limit, reset the limit to pageSize and call the method again
        # + Find the total amount of pages possible based on count and limit
        if params["count"].to_s.empty?
            params["count"] = resp["pageInfo"]["totalResults"]
            params["page"] = "1"
            pageSize = getPageSize(params["count"].to_i, params["limit"].to_i)
            params["limit"] = pageSize - 1
            params["last_page"] = ((params["count"].to_i - (pageSize-1)*2)/(pageSize-2)) + 3;
            return getByPlaylist(params)
        end

        last_page = params["last_page"].to_i

        # Configure the data
        # + If first page, put in data for nextPage tile
        # + If last page, put in data for prevPage tile
        # + If middle page, put in data for both tiles
        data = []
        if params["page"] != "1"
            if params["page"].to_i - 1 == 1 && params["last_page"] != "2"
                limit = params['limit'].to_i + 1
            elsif params["page"].to_i == params["last_page"]
                limit = params['limit'].to_i -1
            else
                limit = params['limit']
            end
            prev_page = {}
            prev_page["title"] = "Previous"
            prev_page["id"] = ""
            prev_page["icon"] = "/prevPage.gif"
            prev_page["layout"] = "/youtube/getByPlaylist?&limit=#{limit}&id=#{params["id"]}&count=#{params['count']}&page=#{params['page'].to_i-1}&token=#{resp['prevPageToken']}"
            prev_page["layout"] += "&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
            data.push(prev_page) 
        end
        for sub in resp["items"]
            sub_data = {}
            sub_data["title"] = sub["snippet"]["title"]
            sub_data["id"] = sub["snippet"]["resourceId"]["videoId"]
            sub_data["icon"] = sub["snippet"]["thumbnails"] != nil ? sub["snippet"]["thumbnails"]["high"]["url"] : "/plugins/youtube/images/no-video.jpg"
            sub_data["layout"] = ""
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
            next_page["layout"] = "/youtube/getByPlaylist?limit=#{limit}&id=#{params["id"]}&count=#{params['count']}&page=#{params['page'].to_i+1}&token=#{resp['nextPageToken']}" 
            next_page["layout"] += "&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
            data.push(next_page)
        end

        return data.to_json
    end

    def getWatchLater(params)
        #== Params
        # *id*: the id of the channel that you want to return videos from
        # *limit*: the limit for the amount of tiles that will be on the page
        params["id"] = @watchlater
        return getByPlaylist(params)
    end

    def getHistory(params)
        #== Params
        # *id*: the id of the channel that you want to return videos from
        # *limit*: the limit for the amount of tiles that will be on the page
        params["id"] = @watchhistory
        return getByPlaylist(params)
    end
end
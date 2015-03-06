class Twitch
    def initialize()
        require 'rest-client'
        require 'uri'
        @client_id = "gvj6f3kx74rhalibxzbhr58s127j5c4"
        @client_secret = ""
        @access_token = "xe917otldfycl6vu04jxsecj10l5zg"
        @refresh_token = "eyJfaWQiOiI4NzI1NTQwNCIsIl91dWlkIjoiMjJiODNmOGUtNTJkMy00MWY2LWI3OWEtNWYzZGFjMGU4ZTEyIn0=%7HAsA5sr8kIYLoTx0DbVEpsYMZ2HgEhhAwqu3FNr5x0="
        @username = "rhyme13"
    end

    def auth()

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

    def getFollowing(params)
        #== Params
        # *limit*: the limit for the amount of tiles that will be on the page
        # offset: the offset so that the results are started at the correct page
        # count: the total count of the resource
        # page: 1,2,3,4,...

        req_params = {}
        req_params["limit"] = params["limit"]
        req_params["offset"] = params["offset"]

        resp = RestClient.get("https://api.twitch.tv/kraken/users/#{@username}/follows/channels",:params => req_params, :authorization => "OAuth #{@access_token}")
        json = JSON.parse(resp)

        following = json['follows']

        # + If the the total count wasn't passed, find it from the response. 
        # + Find the ideal pageSize using the getPageSize method. 
        # + pageSize != limit, reset the limit to pageSize and call the method again
        if params["count"].to_s.empty?
            params["count"] = json["_total"]
            params["page"] = "1"
            pageSize = getPageSize(params["count"].to_i, params["limit"].to_i)
            params["limit"] = pageSize - 1
            params["offset"] = 0
            params["last_page"] = ((params["count"].to_i - (pageSize-1)*2)/(pageSize-2)) + 3;
            following = following.slice(0,params["limit"].to_i)
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
            elsif params["page"].to_i == params["last_page"]
                limit = params['limit'].to_i - 1
            else
                limit = params['limit']
            end
            prev_page = {}
            prev_page["title"] = "Previous"
            prev_page["id"] = ""
            prev_page["icon"] = "/prevPage.gif"
            prev_page["layout"] = "/twitch/getFollowing?limit=#{limit}&count=#{params['count']}&page=#{params['page'].to_i-1}"
            prev_page["layout"] += "&offset=#{params['offset'].to_i-params['limit'].to_i}&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
            data.push(prev_page) 
        end
        for channel in following
            sub_data = {}
            sub_data["title"] = channel["channel"]["display_name"]
            sub_data["id"] = channel["channel"]["name"]
            sub_data["icon"] = channel["channel"]["logo"]
            sub_data["layout"] = "channels-followed"
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
            next_page["layout"] = "/twitch/getFollowing?limit=#{limit}&count=#{params['count']}&page=#{params['page'].to_i+1}" 
            next_page["layout"] += "&offset=#{params['offset'].to_i+params['limit'].to_i}&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
            data.push(next_page)
        end

        return data.to_json
    end

    def getChannelVideos(params)
        #== Params
        # *id*: the 
        # *limit*: the limit for the amount of tiles that will be on the page
        # offset: the offset so that the results are started at the correct page
        # count: the total count of the resource
        # page: 1,2,3,4,...

        req_params = {}
        req_params["limit"] = params["limit"]
        req_params["offset"] = params["offset"]
        req_params["broadcasts"] = "true"

        resp = RestClient.get("https://api.twitch.tv/kraken/channels/#{params['id']}/videos",:params => req_params, :authorization => "OAuth #{@access_token}")
        json = JSON.parse(resp)

        videos = json['videos']

        # + If the the total count wasn't passed, find it from the response. 
        # + Find the ideal pageSize using the getPageSize method. 
        # + pageSize != limit, reset the limit to pageSize and call the method again
        if params["count"].to_s.empty?
            params["count"] = json["_total"]
            params["page"] = "1"
            pageSize = getPageSize(params["count"].to_i, params["limit"].to_i)
            params["limit"] = pageSize - 1
            params["offset"] = 0
            params["last_page"] = ((params["count"].to_i - (pageSize-1)*2)/(pageSize-2)) + 3;
            videos = videos.slice!(0,params["limit"].to_i)
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
            elsif params["page"].to_i == params["last_page"]
                limit = params['limit'].to_i - 1
            else
                limit = params['limit']
            end
            prev_page = {}
            prev_page["title"] = "Previous"
            prev_page["id"] = ""
            prev_page["icon"] = "/prevPage.gif"
            prev_page["layout"] = "/twitch/getChannelVideos?limit=#{limit}&count=#{params['count']}&page=#{params['page'].to_i-1}&id=#{params['id']}"
            prev_page["layout"] += "&offset=#{params['offset'].to_i-params['limit'].to_i}&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
            data.push(prev_page) 
        end
        for video in videos
            sub_data = {}
            sub_data["title"] = video["title"]
            sub_data["id"] = video["url"]
            sub_data["icon"] = video["preview"]
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
            next_page["layout"] = "/twitch/getChannelVideos?limit=#{limit}&count=#{params['count']}&page=#{params['page'].to_i+1}&id=#{params['id']}" 
            next_page["layout"] += "&offset=#{params['offset'].to_i+params['limit'].to_i}&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
            data.push(next_page)
        end

        return data.to_json
    end

    def getTopGames(params)
        #== Params
        # *limit*: the limit for the amount of tiles that will be on the page
        # offset: the offset so that the results are started at the correct page
        # count: the total count of the resource
        # page: 1,2,3,4,...

        req_params = {}
        req_params["limit"] = params["limit"]
        req_params["offset"] = params["offset"]

        resp = RestClient.get("https://api.twitch.tv/kraken/games/top",:params => req_params, :authorization => "OAuth #{@access_token}")
        json = JSON.parse(resp)

        top_games = json['top']

        # + If the the total count wasn't passed, find it from the response. 
        # + Find the ideal pageSize using the getPageSize method. 
        # + pageSize != limit, reset the limit to pageSize and call the method again
        if params["count"].to_s.empty?
            params["count"] = json["_total"]
            params["page"] = "1"
            pageSize = getPageSize(params["count"].to_i, params["limit"].to_i)
            params["limit"] = pageSize - 1
            params["offset"] = 0
            params["last_page"] = ((params["count"].to_i - (pageSize-1)*2)/(pageSize-2)) + 3;
            top_games = top_games.slice(0,params["limit"].to_i)
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
            elsif params["page"].to_i == params["last_page"]
                limit = params['limit'].to_i - 1
            else
                limit = params['limit']
            end
            prev_page = {}
            prev_page["title"] = "Previous"
            prev_page["id"] = ""
            prev_page["icon"] = "/prevPage.gif"
            prev_page["layout"] = "/twitch/getTopGames?limit=#{limit}&count=#{params['count']}&page=#{params['page'].to_i-1}"
            prev_page["layout"] += "&offset=#{params['offset'].to_i-params['limit'].to_i}&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
            data.push(prev_page) 
        end
        for game in top_games
            sub_data = {}
            sub_data["title"] = game["game"]["name"]
            sub_data["id"] = game["game"]["name"]
            sub_data["icon"] = game["game"]["box"]["large"]
            sub_data["layout"] = "games-list"
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
            next_page["layout"] = "/twitch/getTopGames?limit=#{limit}&count=#{params['count']}&page=#{params['page'].to_i+1}" 
            next_page["layout"] += "&offset=#{params['offset'].to_i+params['limit'].to_i}&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
            data.push(next_page)
        end

        return data.to_json
    end

    def getTopVideos(params)
        #== Params
        # *id*: the 
        # *limit*: the limit for the amount of tiles that will be on the page
        # offset: the offset so that the results are started at the correct page
        # count: the total count of the resource
        # page: 1,2,3,4,...

        req_params = {}
        req_params["limit"] = params["limit"]
        req_params["offset"] = params["offset"]
        req_params["broadcasts"] = "true"

        resp = RestClient.get("https://api.twitch.tv/kraken/videos/top",:params => req_params, :authorization => "OAuth #{@access_token}")
        json = JSON.parse(resp)

        videos = json['videos']

        # + If the the total count wasn't passed, find it from the response. 
        # + Find the ideal pageSize using the getPageSize method. 
        # + pageSize != limit, reset the limit to pageSize and call the method again
        if params["count"].to_s.empty?
            params["count"] = "1000000"
            params["last_page"] = "1000"
            params["page"] = "1"
            params["limit"] = params["limit"].to_i - 1
            params["offset"] = 0
            videos = videos.slice!(0,params["limit"].to_i)
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
            elsif params["page"].to_i == params["last_page"]
                limit = params['limit'].to_i - 1
            else
                limit = params['limit']
            end
            prev_page = {}
            prev_page["title"] = "Previous"
            prev_page["id"] = ""
            prev_page["icon"] = "/prevPage.gif"
            prev_page["layout"] = "/twitch/getTopVideos?limit=#{limit}&count=#{params['count']}&page=#{params['page'].to_i-1}"
            prev_page["layout"] += "&offset=#{params['offset'].to_i-params['limit'].to_i}&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
            data.push(prev_page) 
        end
        for video in videos
            sub_data = {}
            sub_data["title"] = video["title"]
            sub_data["id"] = video["url"]
            sub_data["icon"] = video["preview"]
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
            next_page["layout"] = "/twitch/getTopVideos?limit=#{limit}&count=#{params['count']}&page=#{params['page'].to_i+1}" 
            next_page["layout"] += "&offset=#{params['offset'].to_i+params['limit'].to_i}&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
            data.push(next_page)
        end

        return data.to_json
    end

    def getTopStreams(params)
        #== Params
        # *id*: the 
        # *limit*: the limit for the amount of tiles that will be on the page
        # offset: the offset so that the results are started at the correct page
        # count: the total count of the resource
        # page: 1,2,3,4,...

        req_params = {}
        req_params["limit"] = params["limit"]
        req_params["offset"] = params["offset"]

        resp = RestClient.get("https://api.twitch.tv/kraken/streams/featured",:params => req_params, :authorization => "OAuth #{@access_token}")
        json = JSON.parse(resp)

        streams = json['featured']

        # + If the the total count wasn't passed, find it from the response. 
        # + Find the ideal pageSize using the getPageSize method. 
        # + pageSize != limit, reset the limit to pageSize and call the method again
        if params["count"].to_s.empty?
            params["count"] = "30"
            params["last_page"] = "2"
            params["page"] = "1"
            params["limit"] = params["limit"].to_i - 1
            params["offset"] = 0
            streams = streams.slice!(0,params["limit"].to_i)
        end

        # Find the total amount of pages possible based on count and limit. Also
        # caulculate offset
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
            prev_page["layout"] = "/twitch/getTopStreams?limit=#{limit}&count=#{params['count']}&page=#{params['page'].to_i-1}"
            prev_page["layout"] += "&offset=#{params['offset'].to_i-params['limit'].to_i}&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
            data.push(prev_page) 
        end
        for stream in streams
            sub_data = {}
            sub_data["title"] = stream["title"]
            sub_data["id"] = stream["stream"]["channel"]["url"]
            sub_data["icon"] = stream["stream"]["preview"]["large"]
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
            next_page["layout"] = "/twitch/getTopStreams?limit=#{limit}&count=#{params['count']}&page=#{params['page'].to_i+1}" 
            next_page["layout"] += "&offset=#{params['offset'].to_i+params['limit'].to_i}&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
            data.push(next_page)
        end

        return data.to_json
    end

    def getByGame(params)
        #== Params
        # *id*: the name of the game that you want to return streams for
        # *limit*: the limit for the amount of tiles that will be on the page
        # offset: the offset so that the results are started at the correct page
        # count: the total count of the resource
        # page: 1,2,3,4,...

        req_params = {}
        req_params["limit"] = params["limit"]
        req_params["offset"] = params["offset"]
        req_params["game"] = params["id"] # already automatically encoded when sent in sinatra


        resp = RestClient.get("https://api.twitch.tv/kraken/streams",:params => req_params, :authorization => "OAuth #{@access_token}")
        json = JSON.parse(resp)

        streams = json['streams']

        # + If the the total count wasn't passed, find it from the response. 
        # + Find the ideal pageSize using the getPageSize method. 
        # + pageSize != limit, reset the limit to pageSize and call the method again
        if params["count"].to_s.empty?
            params["count"] = json["_total"]
            puts params["count"]
            params["page"] = "1"
            pageSize = getPageSize(params["count"].to_i, params["limit"].to_i)
            puts pageSize.inspect
            params["limit"] = pageSize - 1
            params["offset"] = 0
            params["last_page"] = ((params["count"].to_i - (pageSize-1)*2)/(pageSize-2)) + 3;
            streams = streams.slice!(0,params["limit"].to_i)
        end

        # Find the total amount of pages possible based on count and limit. Also
        # caulculate offset
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
            prev_page["layout"] = "/twitch/getByGame?limit=#{limit}&count=#{params['count']}&page=#{params['page'].to_i-1}&id=#{params['id']}"
            prev_page["layout"] += "&offset=#{params['offset'].to_i-params['limit'].to_i}&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
            data.push(prev_page) 
        end
        for stream in streams
            sub_data = {}
            sub_data["title"] = stream["channel"]["status"]
            sub_data["id"] = stream["channel"]["url"]
            sub_data["icon"] = stream["preview"]["large"]
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
            next_page["layout"] = "/twitch/getByGame?limit=#{limit}&count=#{params['count']}&page=#{params['page'].to_i+1}&id=#{params['id']}" 
            next_page["layout"] += "&offset=#{params['offset'].to_i+params['limit'].to_i}&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
            data.push(next_page)
        end

        return data.to_json
    end

    def getResourceUrl(id)
        return id
    end
end
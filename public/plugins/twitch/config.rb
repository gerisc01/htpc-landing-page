class Twitch
    def initialize()
        require 'rest-client'
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

    def getFollowing(params)
        #== Params
        # *limit*: the limit for the amount of tiles that will be on the page
        # count: the total count of the resource
        # page: 1,2,3,4,...
        resp = RestClient.get("https://api.twitch.tv/kraken/users/#{@username}/follows/channels",:authorization => "OAuth #{@access_token}")
        json = JSON.parse(resp)

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
            prev_page["layout"] = "/twitch/getFollowing?limit=#{limit}&count=#{params['count']}&page=#{params['page'].to_i-1}&token=#{resp['prevPageToken']}"
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
            next_page["layout"] = "/twitch/getFollowing?limit=#{limit}&count=#{params['count']}&page=#{params['page'].to_i+1}&token=#{resp['nextPageToken']}" 
            next_page["layout"] += "&last_page=#{last_page}" # adding in the last_page variable as a temporary solution
            data.push(next_page)
        end

        return data.to_json
    end

    def getResourceUrl(id)
        return "https://www.youtube.com/watch?v=" + id
    end
end
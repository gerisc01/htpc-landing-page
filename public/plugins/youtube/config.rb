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

	def getChannel(id, limit, offset)
		channel = @client.execute!(
			:api_method => @youtube_discovered_api.subscriptions.list,
			:parameters => {
				:part => "snippet",
				:mine => true,
				:maxResults => 6
			}
		)
		resp = JSON.parse(channel.response.body)

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
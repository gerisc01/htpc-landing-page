require 'json'
require 'uri'
require 'time'
require 'rest-client'

artists = File.read("artists.txt")

@client_id = "6a4ec190bc1b405099a8256f17c456d1"
@client_secret = "e9f5adc49029473f93add702787b676f"
@refresh_token = "AQCrqtaGwPNV2OM1had6fR6ezjBnxXAbasFDFvVX6xAtuV53YJ777KLENEoGA4gAe_Mu2O_XSdKQEuIUHDXU9BRfryuIXEhvidcULZC2xrR1c27WiWkEF6LShTzie2NJFEw"
@token_expire = Time.new(1,1,1)

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

def get_artist_id(artist)
    if Time.now > @token_expire
        @access_token = auth()
        puts @access_token
    end

    begin
        resp = RestClient.get("https://api.spotify.com/v1/search?q=#{URI.escape(artist)}&type=artist&market=from_token", :authorization => "Bearer #{@access_token}")
    rescue RestClient::Exception => ex
        puts ex.inspect
    end
    json = JSON.parse(resp)
    items = json["artists"]["items"]

    id = ""
    if !items.empty? && items[0]["name"].downcase == artist.downcase.strip
        id = items[0]["id"]
    end

    puts "We couldn't find an exact match on Spotify for '#{artist}'" if id == ""
    return id
end

count = 0
while artist = artists[/(^(?:(?!::).)*?)$/]
    artist_id = get_artist_id(artist)
    artists.gsub!(artist, artist + "::" + artist_id)
    if count%10 == 0
        File.open("artists.txt", 'w') do |f|
            f.write(artists)
        end
        sleep(15)
    end
    count += 1
end

File.open("artists.txt", 'w') do |f|
    f.write(artists)
end
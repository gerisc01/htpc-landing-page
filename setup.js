var jsoninput = '{ "tiles" : { "youtube" : { "id" : "youtube", "icon" : "images/youtube.jpg", "layout" : "home" }, "twitch" : { "id" : "twitch", "icon" : "images/twitch.jpeg", "layout" : "home" }, "pocketcasts" : { "id" : "pocketcasts", "icon" : "images/pocketcasts.png", "layout" : "home" }, "mlb-at-bat" : { "id" : "mlb-at-bat", "icon" : "images/mlb-at-bat.png", "layout" : "home" }, "mls-live" : { "id" : "mls-live", "icon" : "images/mls-live.png", "layout" : "home" }, "nbc-sports" : { "id" : "nbc-sports", "icon" : "images/nbc-sports.jpg", "layout" : "home" } }, "layouts" : { "home" : ["youtube","twitch","pocketcasts","mlb-at-bat","mls-live","nbc-sports"] } }';
var youtubeinput = '{ "tiles" : { "subscribers" : { "title" : "Subscriptions", "id": "", "icon": "images/subscriptions.png", "layout": "subscribers" }, "playlists" : { "title" : "Playlists", "id": "", "icon": "images/playlists.png", "layout": "playlists" }, "watchlater" : { "title" : "Watch Later", "id": "", "icon": "images/watchlater.png", "layout": "watchlater" }, "popular" :{ "title" : "Popular", "id": "", "icon": "images/popular.jpg", "layout": "popular" }, "subscribers-list" : "getSubs()", "playlists-list" : "getPlaylists()", "videos-by-channel" : "getVideosByChannel()", "videos-by-playlist" : "getVideosByPlaylist()", "watchlater-videos" : "getWatchLaterVideos()", "popular-videos" : "getPopularVideos()" }, "layouts" : { "home" : ["subscribers","playlists","watchlater","popular"], "subscribers" : "subscribers-list", "playlists" : "playlists-list", "watchlater" : "watchlater-videos", "popular" : "popular-videos", "subscribers-list" : "videos-by-channel", "playlists-list" : "videos-by-playlist" } }';
var tileCount = 0;
var currentPlugin = null;

// Document.ready function
$(function() {
  setupGrid(jsoninput, "home");
});

function setupGrid(config, layout) {
  // Load plugin file
  var json = JSON.parse(config);

  /***************************************************************************
                          CREATE THE MEDIA TILES
  ****************************************************************************/
  var keys = json.layouts[layout];
  for (var i = 0; i < keys.length; i++) {
    var key = keys[i];
    jQuery('<div/>', {
          id: tileCount,
          class: "img-wrapper",
          title: key
      }).appendTo('#load-container');

      var imgFile;
      if (currentPlugin === null) {
        imgFile = "plugins/" + key + "/" + json.tiles[key].icon;
      } else {
        imgFile = "plugins/" + currentPlugin + "/" + json.tiles[key].icon;
      }
      jQuery('<img/>', {
        class: "tile",
        src: imgFile,
        'data-adaptive-background': '1'
      }).appendTo('#'+tileCount);

      jQuery('<input/>', {
        id: "layout",
        type: "hidden",
        text: json.tiles[key].layout
      }).appendTo('#'+tileCount);

      tileCount += 1;
  }

  $("#0").addClass("selected");
  $.adaptiveBackground.run();

  /* Add the CSS needed to make the tiles fit on one page with no scrolling */

  // Get the grid dimensions
  var dimensions = getGridDimensions(tileCount);
  // If the dimensions did not return a usable grid, try again
  var attempts = 1;
  while (dimensions[0] === 0) { // if the grid width is 0, no grid layouts were found
    dimensions = getGridDimensions(tileCount + attempts);
    attempts += 1;
  }
  var gridWidth = dimensions[0];
  var gridHeight = dimensions[1];

  var tileHeight = 100/gridHeight;
  var tileWidth = 100/gridWidth;
  $(".img-wrapper").css({"height" : tileHeight+"%", "width" : tileWidth+"%"});

  /***************************************************************************
                       ACTIVATE KEYBOARD NAVIGATION
  ****************************************************************************/
  $("body").keydown(function(e) {
    // If any of the directional keys are pressed
    if ($.inArray(e.keyCode,[13,37,38,39,40]) != -1) {
      var currentSelected = $(".selected")[0];
      var currentId = parseInt(currentSelected.id);
      var currentRow = Math.floor((currentId)/gridWidth);
    }

    if(e.keyCode == 37) { // left
      var newId = (((currentId - 1) + tileCount) % gridWidth) + currentRow * gridWidth;
      $(".selected").removeClass("selected");
      $("#"+newId.toString()).addClass("selected");
    }
    else if (e.keyCode == 38) { // up
      var newId = ((currentId - (gridWidth)) + tileCount) % tileCount;
      $(".selected").removeClass("selected");
      $("#"+newId.toString()).addClass("selected");
    }
    else if(e.keyCode == 39) { // right
      var newId = (((currentId + 1) + tileCount) % gridWidth) + currentRow * gridWidth;
      $(".selected").removeClass("selected");
      $("#"+newId.toString()).addClass("selected");
    }
    else if(e.keyCode == 40) { // down
      var newId = ((currentId + (gridWidth)) + tileCount) % tileCount;
      $(".selected").removeClass("selected");
      $("#"+newId.toString()).addClass("selected");
    }
    // If it is the enter key that is pressed
    else if (e.keyCode == 13) {
      if (currentPlugin === null) {currentPlugin = currentSelected.title;}
      console.log(currentSelected.title);
      // var configLocation = "plugins/" + currentPlugin + "/config.json"
      // $.getJSON(configLocation, function(json) {         
      //   var nextLayout = ;
      // });
      var nextLayout = $(".selected #layout").text();
      clearLayout();
      setupGrid(youtubeinput, nextLayout);
      // Create the link from the div to go to the next grid pattern
    }
  });
}

function clearLayout() {
  tileCount = 0;
  $("#load-container").empty();
  $("body").off("keydown");
}

function getGridDimensions(tiles) {
    var width = 0;
    var height = 0;
    for (i = 2; i < tiles; i++) {
      var possDims = {};
      var division = (tiles/i).toString();
      if (division.indexOf(".") == -1) {
        possDims[division] = i;
      }

      for (var key in possDims) {
        if (possDims.hasOwnProperty(key)) {
          if (width == 0 || key > width || 
            Math.abs(width-height) > Math.abs(key-possDims[key])) {
            width = key;
            height = possDims[key];
          }
        }
      }
    }
  return [parseInt(width), parseInt(height)];
}
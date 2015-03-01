var jsoninput = '{ "tiles" : { "youtube" : { "title" : "YouTube", "id" : "youtube", "icon" : "images/youtube.jpg", "layout" : "home" }, "twitch" : { "title" : "Twitch", "id" : "twitch", "icon" : "images/twitch.jpeg", "layout" : "home" }, "pocketcasts" : { "title" : "PocketCasts", "id" : "pocketcasts", "icon" : "images/pocketcasts.png", "layout" : "home" }, "mlb-at-bat" : { "title" : "MLB At Bat", "id" : "mlb-at-bat", "icon" : "images/mlb-at-bat.png", "layout" : "home" }, "mls-live" : { "title" : "MLS Live", "id" : "mls-live", "icon" : "images/mls-live.png", "layout" : "home" }, "nbc-sports" : { "title" : "NBC Sports", "id" : "nbc-sports", "icon" : "images/nbc-sports.jpg", "layout" : "home" } }, "layouts" : { "home" : ["youtube","twitch","pocketcasts","mlb-at-bat","mls-live","nbc-sports"] } }';
var youtubeinput = '{ "tiles" : { "subscribers" : { "title" : "Subscriptions", "id": "", "icon": "images/subscriptions.png", "layout": "subscribers" }, "playlists" : { "title" : "Playlists", "id": "", "icon": "images/playlists.png", "layout": "playlists" }, "watchlater" : { "title" : "Watch Later", "id": "", "icon": "images/watchlater.png", "layout": "watchlater" }, "popular" :{ "title" : "Popular", "id": "", "icon": "images/popular.jpg", "layout": "popular" }, "subscribers-list" : "getSubs()", "playlists-list" : "getPlaylists()", "videos-by-channel" : "getVideosByChannel()", "videos-by-playlist" : "getVideosByPlaylist()", "watchlater-videos" : "getWatchLaterVideos()", "popular-videos" : "getPopularVideos()" }, "layouts" : { "home" : ["subscribers","playlists","watchlater","popular"], "subscribers" : "subscribers-list", "playlists" : "playlists-list", "watchlater" : "watchlater-videos", "popular" : "popular-videos", "subscribers-list" : "videos-by-channel", "playlists-list" : "videos-by-playlist" } }';
var tileCount = 0;
var currentPlugin = null;
var configObj = null;

$.ajaxSetup({
   async: false
 });

// Document.ready function
$(function() {
  configObj = getGridConfig("config.json", "home");
  setupGrid(configObj, "home");
});

function getGridConfig(config, layout) {
  var configArray = [];
  $.getJSON(config, function (json) {
    var currentLayout = json.layouts[layout];
    if (typeof currentLayout === 'string') {
      var tileFunction = json.tiles[currentLayout]
      var endpoint = "/" + currentPlugin + "/" + tileFunction;
      resp = $.get(endpoint);
      configArray = resp.responseJSON
    } else {
      for (var i = 0; i < currentLayout.length; i++) {
        var key = currentLayout[i];
        configArray.push(json.tiles[key]);
      }
    }
  });
  return configArray;
}

function setupGrid(config, layout) {
  // Using the tileMap to easily access information for
  // the tiles after one is selected.
  tileMap = {}
  /***************************************************************************
                          CREATE THE MEDIA TILES
  ****************************************************************************/
  for (var i = 0; i < config.length; i++) {
    var plugin = config[i];
    jQuery('<div/>', {
          id: tileCount,
          class: "img-wrapper",
          title: plugin.id
      }).appendTo('#load-container');

      var imgFile;
      var tileClass = "tile-pic";
      var coloredBackground = '0';
      if (currentPlugin === null) {
        imgFile = "plugins/" + plugin.id + "/" + plugin.icon;
        tileClass = "plugintile";
        coloredBackground = '1';
      } else if (/https?:\/\//.exec(plugin.icon) != null) {
        imgFile = plugin.icon
      } else {
        imgFile = "plugins/" + currentPlugin + "/" + plugin.icon;
      }
      jQuery('<img/>', {
        class: tileClass,
        src: imgFile,
        'data-adaptive-background': coloredBackground
      }).appendTo('#'+tileCount);

      if (currentPlugin != null) {
        jQuery('<h2/>', {
          class: "center-title",
          text: plugin.title
        }).appendTo('#'+tileCount);
      }

      jQuery('<input/>', {
        id: "layout",
        type: "hidden",
        value: plugin.layout
      }).appendTo('#'+tileCount);

      tileMap[plugin.id] = plugin;
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
    var currentSelected;
    var currentId;
    var currentRow;
    var newId;
    // If any of the directional keys are pressed
    if ($.inArray(e.keyCode,[8,13,37,38,39,40]) != -1) {
      currentSelected = $(".selected")[0];
      currentId = parseInt(currentSelected.id);
      currentRow = Math.floor((currentId)/gridWidth);
    }

    if(e.keyCode == 37) { // left
      newId = (((currentId - 1) + tileCount) % gridWidth) + currentRow * gridWidth;
      $(".selected").removeClass("selected");
      $("#"+newId.toString()).addClass("selected");
    }
    else if (e.keyCode == 38) { // up
      newId = ((currentId - (gridWidth)) + tileCount) % tileCount;
      $(".selected").removeClass("selected");
      $("#"+newId.toString()).addClass("selected");
    }
    else if(e.keyCode == 39) { // right
      newId = (((currentId + 1) + tileCount) % gridWidth) + currentRow * gridWidth;
      $(".selected").removeClass("selected");
      $("#"+newId.toString()).addClass("selected");
    }
    else if(e.keyCode == 40) { // down
      newId = ((currentId + (gridWidth)) + tileCount) % tileCount;
      $(".selected").removeClass("selected");
      $("#"+newId.toString()).addClass("selected");
    }
    else if (e.keyCode == 13) { // Enter
      if (currentPlugin === null) {
        currentPlugin = currentSelected.title;
        $.get("/"+currentPlugin+"/init");
      }
      var configLocation = currentPlugin === null ? "config.json" : "plugins/" + currentPlugin + "/config.json";
      var nextLayout = $(".selected #layout").val();
      addToNavbar(tileMap[currentSelected.title].title, currentPlugin, nextLayout);
      clearLayout();
      var configObj = getGridConfig(configLocation, nextLayout);
      setupGrid(configObj, nextLayout);
    }
    else if (e.keyCode == 8 && !$(e.target).is("input, textarea")) {
        e.preventDefault();
        if ($("ul.nav li").size() > 1) {
          var prevLayout = $("ul.nav li").eq(-2).children("#layout").val();
          if ($("ul.nav li").eq(-2).children("#plugin").val() === "") {
            currentPlugin = null;
          }

          var configLocation = currentPlugin === null ? "config.json" : "plugins/" + currentPlugin + "/config.json";
          clearLayout();
          var configObj = getGridConfig(configLocation, prevLayout);
          setupGrid(configObj, prevLayout);
          $("ul.nav li").eq(-1).remove();
          $("ul.nav li").eq(-1).addClass("active");
        }
    }
  });
}

function clearLayout() {
  tileCount = 0;
  $("#load-container").empty();
  $("body").off("keydown");
}

function addToNavbar(title, plugin, layout) {
  $("ul.nav li").eq(-1).removeClass("active");
  
  jQuery("<li/>", {
    class: "active"
  }).appendTo("ul.nav");

  jQuery("<a/>", {
    href: "#",
    text: title
  }).appendTo("ul.nav li.active");

  jQuery("<input/>", {
    id: "plugin",
    type: "hidden",
    value: plugin
  }).appendTo("ul.nav li.active");

  jQuery("<input/>", {
    id: "layout",
    type: "hidden",
    value: layout
  }).appendTo("ul.nav li.active");
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
          if (width === 0 || key > width ||
            Math.abs(width-height) > Math.abs(key-possDims[key])) {
            width = key;
            height = possDims[key];
          }
        }
      }
    }
  return [parseInt(width), parseInt(height)];
}
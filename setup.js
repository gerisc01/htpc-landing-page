var jsoninput = '{"amount": 6,"pluginsLocation" : "plugins","plugins" : {"youtube" : {"name" : "YouTube","folder" : "youtube","icon" : "youtube.jpg","config" : "youtube.json"},"twitch" : {"name" : "Twitch","folder" : "twitch","icon" : "twitch.jpeg","config" : "twitch.json"},"pocketcasts" : {"name" : "PocketCasts","folder" : "pocketcasts","icon" : "pocketcasts.png","config" : "pocketcasts.json"},"mlb-at-bat" : {"name" : "MLB At Bat","folder" : "mlb-at-bat","icon" : "mlb-at-bat.png","config" : "mlb-at-bat.json"},"mls-live" : {"name" : "MLS Live","folder" : "mls-live","icon" : "mls-live.png","config" : "mls-live.json"},"nbc-sports" : {"name" : "NBC Sports","folder" : "nbc-sports","icon" : "nbc-sports.jpg","config" : "nbc-sports.json"}}}';
var tileCount;
var pluginsLocation;

// Document.ready function
$(function() {
  // Load plugin file
  var json = JSON.parse(jsoninput);
  tileCount = json.amount;
  pluginsLocation = json.pluginsLocation;

  /***************************************************************************
                          CREATE THE MEDIA TILES
  ****************************************************************************/
  var counter = 0;
  for (var key in json.plugins) {
    if (json.plugins.hasOwnProperty(key)) {
      jQuery('<div/>', {
          id: counter,
          class: "img-wrapper",
          title: key
      }).appendTo('#load-container');

      var img_file = pluginsLocation + "/" + json.plugins[key].folder + "/" + json.plugins[key].icon;
      jQuery('<img/>', {
        class: "tile",
        src: img_file,
        'data-adaptive-background': '1'
      }).appendTo('#'+counter);
      counter += 1;
    }
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
      console.log(currentSelected.title);
      // Create the link from the div to go to the next grid pattern
    }
  });
});


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
var tileCount = 0;
var maxTilesPerPage = 16;
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

function getGridConfig(config, layout, id) {
  var configArray = [];
  // If config is null, the passed layout is a endpoint for the nextPage
  // If the layout is null, the passed id should be opened in a new page
  if (config === null) {
    resp = $.get(layout);
    configArray = resp.responseJSON;
  } else {
    $.getJSON(config, function (json) {
      var currentLayout = json.layouts[layout];
      if (typeof currentLayout === 'string') {
        var tileFunction = json.tiles[currentLayout];
        var endpoint = "/" + currentPlugin + "/" + tileFunction + "?limit=" + maxTilesPerPage;
        if (id !== undefined || id !== "") {
          endpoint += "&id=" + id;
        }
        resp = $.get(endpoint);
        configArray = resp.responseJSON;
      } else {
        for (var i = 0; i < currentLayout.length; i++) {
          var key = currentLayout[i];
          configArray.push(json.tiles[key]);
        }
      }
    });
  }
  return configArray;
}

function setupGrid(config, layout) {
  // Using the tileMap to easily access information for
  // the tiles after one is selected.
  tileMap = {};
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
      } else if (/https?:\/\//.exec(plugin.icon) !== null || plugin.icon.indexOf("/") === 0) {
        imgFile = plugin.icon;
      } else {
        imgFile = "plugins/" + currentPlugin + "/" + plugin.icon;
      }
      jQuery('<img/>', {
        class: tileClass,
        src: imgFile,
        'data-adaptive-background': coloredBackground
      }).appendTo('#'+tileCount);

      if (currentPlugin != null) {
        jQuery('<p/>', {
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
      if (currentId % gridWidth === 0) {
        newId = currentId + (gridWidth - 1);
      } else {
        newId = currentId - 1;
      }
      if (newId >= tileCount) { newId = tileCount - 1; }

      $(".selected").removeClass("selected");
      $("#"+newId.toString()).addClass("selected");
    }
    else if (e.keyCode == 38) { // up
      if (currentId - gridWidth < 0) {
        newId = currentId + (gridWidth * (gridHeight-1));
      } else {
        newId = currentId - gridWidth;
      }
      if (newId >= tileCount) { newId = tileCount - 1; }

      $(".selected").removeClass("selected");
      $("#"+newId.toString()).addClass("selected");
    }
    else if(e.keyCode == 39) { // right
      newId = currentId + 1;
      if (newId % gridWidth === 0) {
        newId -= gridWidth;
      }
      if (newId >= tileCount) { newId = tileCount - 1; }

      $(".selected").removeClass("selected");
      $("#"+newId.toString()).addClass("selected");
    }
    else if(e.keyCode == 40) { // down
      if (currentId + gridWidth > gridHeight * gridWidth) {
        newId = currentId - (gridWidth * (gridHeight-1));
      } else {
        newId = currentId + gridWidth;
      }
      if (newId >= tileCount) { newId = tileCount - 1; }

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
      if (nextLayout === "") {
        openResource(currentSelected.title);
      } else {
        if (currentSelected.title === "") {
          re = RegExp("^\\/" + currentPlugin + "\\/(.*)\\?");
          if (re.exec(nextLayout) !== null) {
            configLocation = null;
          }
        } else {
          addToNavbar(tileMap[currentSelected.title].title, currentPlugin, nextLayout, currentSelected.title);
        }
        clearLayout();
        var configObj = getGridConfig(configLocation, nextLayout, currentSelected.title);
        setupGrid(configObj, nextLayout);
      }
    }
    else if (e.keyCode == 8 && !$(e.target).is("input, textarea")) {
        e.preventDefault();
        if ($("ul.nav li").size() > 1) {
          var prevLayout = $("ul.nav li").eq(-2).children("#layout").val();
          var id = $("ul.nav li").eq(-2).children("#id").val();
          if ($("ul.nav li").eq(-2).children("#plugin").val() === "") {
            currentPlugin = null;
          }
          var configLocation = currentPlugin === null ? "config.json" : "plugins/" + currentPlugin + "/config.json";
          clearLayout();
          var configObj = getGridConfig(configLocation, prevLayout, id);
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

function addToNavbar(title, plugin, layout, id) {
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

  jQuery("<input/>", {
    id: "id",
    type: "hidden",
    value: id
  }).appendTo("ul.nav li.active");
}

function getGridDimensions(tiles) {
  var width = 0;
  var height = 0;
  for (i = 1; i < 11; i++) {
    if (tiles < i*i) {
      height = i - 1;
      for (j = height; j < 12; j++) {
        if (tiles <= j*height) {
          width = j;
          return [parseInt(width), parseInt(height)];
        }
      }
    }
  }
}

function addNowPlaying() {
  $('body').css('padding-bottom', '50px');

  jQuery('<div/>', {
    class: "now-playing",
    text: "Now Playing"
  }).appendTo('body');
}

function removeNowPlaying() {
  $('body').css('padding-bottom', '0');
  $("div.now-playing").eq(-1).remove();
}

function openResource(id) {
  var endpoint = "/" + currentPlugin + "/getResourceUrl?id=" + id;
  resp = $.get(endpoint);
  url = resp.responseJSON.url;
  window.open(url, '_blank');
}
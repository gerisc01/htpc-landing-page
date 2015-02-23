var tileCount = 9;
var gridCount = tileCount;
var dimensions = getGridDimensions(tileCount);
// If the dimensions did not return a usable grid, try again
var attempts = 1;
while (dimensions[0] == 0) {
  dimensions = getGridDimensions(tileCount + attempts);
  attempts += 1;
}
var gridWidth = dimensions[0];
var gridHeight = dimensions[1];



$(function() {
  $("body").keydown(function(e) {
    if ($.inArray(e.keyCode,[37,38,39,40]) != -1) {
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
  return [width, height];
}
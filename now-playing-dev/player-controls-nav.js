var navDirections = {
    "play-pause" : {
      "left" : "previous",
      "right" : "next"
    },
    "previous" : {
      "down" : "shuffle",
      "right" : "play-pause"
    },
    "next" : {
      "left" : "play-pause",
      "down" : "repeat"
    },
    "shuffle" : {
      "up" : "previous",
      "right" : "repeat"
    },
    "repeat" : {
      "left" : "shuffle",
      "up" : "next"
    }
  };

$(function() {
  $("body").keydown(function(e) {
    if ($("#np-container").length) {
      var currentSelected;
      var currentId;
      var currentRow;
      var newId;
      // If any of the directional keys are pressed
      if ($.inArray(e.keyCode,[8,13,37,38,39,40]) != -1) {
        currentSelected = $(".selected")[0];
        currentId = currentSelected.id;
      }

      if(e.keyCode == 37) { // left
        if (navDirections[currentId]["left"] !== undefined) {
          $(".selected").removeClass("selected");
          $("#"+navDirections[currentId]["left"]).addClass("selected");
        }
      }
      else if (e.keyCode == 38) { // up
        if (navDirections[currentId]["up"] !== undefined) {
          $(".selected").removeClass("selected");
          $("#"+navDirections[currentId]["up"]).addClass("selected");
        }
      }
      else if(e.keyCode == 39) { // right
        if (navDirections[currentId]["right"] !== undefined) {
          $(".selected").removeClass("selected");
          $("#"+navDirections[currentId]["right"]).addClass("selected");
        }
      }
      else if(e.keyCode == 40) { // down
        if (navDirections[currentId]["down"] !== undefined) {
          $(".selected").removeClass("selected");
          $("#"+navDirections[currentId]["down"]).addClass("selected");
        }
      }
      else if (e.keyCode == 13) { // Enter
          if (currentId == "play-pause") {
            var hidden = $("#play-pause img.hidden")[0];
            $("#play-pause img.hidden").removeClass("hidden");
            if (hidden.id === "play") {
              $("#play-pause img#pause").addClass("hidden");
            } else {
              $("#play-pause img#play").addClass("hidden");
            }
          } else if (currentId == "shuffle") {
            console.log("Attempting to change shuffle!");
            var src = $("#shuffle img")[0].src;
            if (src.match(/shuffle.png/)) {
              console.log("Decting standard shuffle");
              src = src.replace("shuffle.png","shuffle-selected.png");
            } else {
              console.log("Decting selected shuffle");
              src = src.replace("shuffle-selected.png","shuffle.png");
            }
            console.log(src);
            $("#shuffle img").attr("src",src);
          }
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

});
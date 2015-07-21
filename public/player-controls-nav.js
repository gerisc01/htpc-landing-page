var ws = new WebSocket("ws://127.0.0.1:4567/nowplaying/ws");

ws.onopen = function() {
  console.log("web socket opened");
};

ws.onmessage = function(event_msg) {
  try {
    var json = $.parseJSON(event_msg.data);
    handleWebhook(json);
  } catch(err) {}
};

function handleWebhook(json) {
  if (json["type"] === "play-pause") {
    togglePlayPause(json["new_state"]);
  }
}

function refreshQueue() {
  $.getJSON("/nowplaying/queue", function(json) {
    queueCallback(json);
  });
}

function queueCallback(json) {
  // Clear the queue of previous tracks before re-adding
  $('.queue ul').empty();

  for (i = 0; i < json.history.length; i++) {
    $("<li/>", {
      text: json.history[i].name,
      class: "history"
    }).appendTo('.queue #previous-tracks');
  }

  $("<li/>", {
    text: json.current.name,
    class: "current"
  }).appendTo('.queue #current-track');

  for (j = 0; j < json.future.length; j++) {
    $("<li/>", {
      text: json.future[j].name,
      class: "future"
    }).appendTo('.queue #future-tracks');
  }
}

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

function togglePlayPause(new_state) {
  var hidden = $("#play-pause img.hidden")[0];
  if (new_state === undefined) {
    $("#play-pause img.hidden").removeClass("hidden");
    if (hidden.id === "play") {
      $("#play-pause img#pause").addClass("hidden");
    } else {
      $("#play-pause img#play").addClass("hidden");
    }
  } else if (new_state === "playing" && hidden.id === "pause") {
    refreshQueue();
    $("#play-pause img#pause").removeClass("hidden");
    $("#play-pause img#play").addClass("hidden");
  } else if (new_state === "paused" && hidden.id === "play") {
    $("#play-pause img#play").removeClass("hidden");
    $("#play-pause img#pause").addClass("hidden");
  }
}

function toggleShuffle(new_state) {
  var src = $("#shuffle img")[0].src;
  if (new_state === undefined) {
    if (src.match(/shuffle.png/)) {
      new_state = "on";
    } else {
      new_state = "off";
    }
  }

  if (new_state === "on") {
    src = src.replace("shuffle.png","shuffle-selected.png");
  } else if (new_state === "off") {
    src = src.replace("shuffle-selected.png","shuffle.png");
  }
  $("#shuffle img").attr("src",src);
}

function toggleRepeat(new_state) {
  var src = $("#repeat img")[0].src;
  if (new_state === undefined) {
    if (src.match(/repeat.png/)) {
      new_state = "on";
    } else {
      new_state = "off";
    }
  }

  if (new_state === "on") {
    src = src.replace("repeat.png","repeat-selected.png");
  } else if (new_state === "off") {
    src = src.replace("repeat-selected.png","repeat.png");
  }
  $("#repeat img").attr("src",src);
}

$(function() {
  refreshQueue();

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
          if (currentId === "play-pause") {
            var hidden = $("#play-pause img.hidden")[0];
            if (hidden.id === "play") {
              $.post("/nowplaying/controls/pause");
            } else {
              $.post("/nowplaying/controls/play");
            }
          } else if (currentId === "next") {
            $.post("/nowplaying/controls/next");
          } else if (currentId === "previous") {
            $.post("/nowplaying/controls/previous");
          } else if (currentId === "shuffle") {
            toggleShuffle();
          } else if (currentId === "repeat") {
            toggleRepeat();
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
var jsoninput = '{"amount": 6,"pluginsLocation" : "plugins","plugins" : {"youtube" : {"name" : "YouTube","folder" : "youtube","icon" : "youtube.jpg","config" : "youtube.json"},"twitch" : {"name" : "Twitch","folder" : "twitch","icon" : "twitch.jpeg","config" : "twitch.json"},"pocketcasts" : {"name" : "PocketCasts","folder" : "pocketcasts","icon" : "pocketcasts.png","config" : "pocketcasts.json"},"mlb-at-bat" : {"name" : "MLB At Bat","folder" : "mlb-at-bat","icon" : "mlb-at-bat.png","config" : "mlb-at-bat.json"},"mls-live" : {"name" : "MLS Live","folder" : "mls-live","icon" : "mls-live.png","config" : "mls-live.json"},"nbc-sports" : {"name" : "NBC Sports","folder" : "nbc-sports","icon" : "nbc-sports.jpg","config" : "nbc-sports.json"}}}';
var tileCount;
var pluginsLocation;

$(function() {
  var json = JSON.parse(jsoninput);
  var counter = 0;
  tileCount = json.amount;
  pluginsLocation = json.pluginsLocation;
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
      //console.log(json.plugins[key]);
    }
  }

  $("#0").addClass("selected");
  $.adaptiveBackground.run();
});
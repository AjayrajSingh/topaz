(function() {
  var entities = [];
  function addJsonLd(item) {
    // prefix @type with @context for context engine compatibility
    if (!item["@type"]) {
      return;
    }
    if (!item["@context"]) {
      return;
    }
    item["@type"] = item["@context"] + "/" + item["@type"];
    entities.push(item);
  }
  for (var script of document.querySelectorAll("script[type='application/ld+json']")) {
    var value;
    try {
      value = JSON.parse(script.textContent);
    } catch(e) {
      continue;
    }
    if (value instanceof Array) {
      for (item of value) {
        addJsonLd(item);
      }
    } else {
      addJsonLd(value);
    }
  }
  return JSON.stringify(entities);
})()

library js_interop_utils;

import "dart:js" as js;

js.JsObject createJsOptionsMap(Map opts) {
  var result = new Map();
  opts.forEach((key, value) {
    if (value != null) {
      result[key] = value;
    }
  });
  return new js.JsObject.jsify(result);
}

library promise_wrapper;

import "dart:async";
import "dart:js" as js;

js.JsObject asyncFunctionToJsPromise(AsyncFunction f) {
  return new js.JsObject(js.context['Promise'], [_promiseExecutorGenerator(f)]);
}

/// Returns a JavaScript Promise executor closure generated from
/// an async function [f].
PromiseExecutor _promiseExecutorGenerator(AsyncFunction f) {
  return (js.JsFunction resolve, js.JsFunction reject) {
    f().then((v) {
      resolve.apply([v]);
    }).catchError((e) {
      reject.apply([e]);
    });
  };
}

/// Returns a JavaScript Promise from a Future.
js.JsObject futureToJsPromise(Future future) {
  return new js.JsObject(js.context['Promise'], [
    (js.JsFunction resolve, js.JsFunction reject) {
      future.then((v) {
        resolve.apply([v]);
      }).catchError((e) {
        reject.apply([e]);
      });
    }
  ]);
}

Future jsPromiseToFuture(js.JsObject promise) {
  var completer = new Completer();

  promise.callMethod("then", [
    (Object value) {
      completer.complete(value);
    }
  ]).callMethod("catch", [
    (Object err) {
      completer.completeError(err);
    }
  ]);

  return completer.future;
}

typedef void PromiseExecutor(js.JsFunction resolve, js.JsFunction reject);

typedef Future AsyncFunction();

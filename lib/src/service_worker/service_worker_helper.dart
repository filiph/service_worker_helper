part of service_worker_helper;

/// Helper to be used from inside the Service Worker.
abstract class ServiceWorkerHelper {
  final js.JsObject _context;
  Clients _clients;

  Clients get clients => _clients;

  ServiceWorkerHelper([js.JsObject context])
      : _context = context != null ? context : js.context {
    _clients = new Clients(_context['clients']);
  }

  Future<Object> fetchJson(String path) async {
    js.JsObject response;
    js.JsObject json;
    try {
      response = await jsPromiseToFuture(js.context.callMethod("fetch", [path]));
    } catch (e) {
      throw wrapServiceWorkerError(e);
    }
    try {
      json = await jsPromiseToFuture(response.callMethod("json"));
    } catch (e) {
      throw new JsonParseError(e);
    }
    return json;
  }

  Future showNotification(String title, String body, String icon, String tag) {
    // self.registration.showNotifcation()
    var selfRegistration = _context['self']['registration'];
    var opts = createJsOptionsMap({"body": body, "icon": icon, "tag": tag});

    return jsPromiseToFuture(
        selfRegistration.callMethod('showNotification', [title, opts]));
  }

  /// Called when we receive a push message. Returns a JavaScript promise that
  /// resolves when work is done so that Service Worker stays alive.
  js.JsObject _handlePushMessage(event) {
    return futureToJsPromise(onPushMessage(event));
  }

  Future onPushMessage(event);

  js.JsObject _handleNotificationClick(event) {
    return futureToJsPromise(onNotificationClick(event));
  }

  Future onNotificationClick(event);

  void run() {
    _context['dartExportedHandlePushMessage'] = _handlePushMessage;
    _context['dartExportedHandleNotificationClick'] = _handleNotificationClick;
  }
}

part of service_worker_helper;

/// Helper to be used from inside the Service Worker.
abstract class ServiceWorkerHelper {
  final js.JsObject _context;
  Clients _clients;

  Clients get clients => _clients;
  js.JsObject get registration => _context['self']['registration'];

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
    var options = createJsOptionsMap({"body": body, "icon": icon, "tag": tag});

    return jsPromiseToFuture(
        registration.callMethod('showNotification', [title, options]));
  }

  Future<List<Notification>> getNotifications({String tag}) async {
    // if (self.registration.getNotifications) {
    //   return self.registration.getNotifications(notificationFilter)
    //   .then(function(notifications) {
    //   });
    // }

    var options = createJsOptionsMap({"tag": tag});
    var jsNotifications;
    try {
      jsNotifications = await jsPromiseToFuture(
          registration.callMethod('getNotifications', [options])
      );
    } catch (e) {
      print(e);
      return const [];
    }
    if (jsNotifications == null) return const [];
    return (jsNotifications as List<js.JsObject>).map((n) => new Notification(n));
  }

  /// Access PushSubscription from inside the service worker.
  Future<Optional<PushSubscription>> getCurrentPushSubscription() async {
    // registration.pushManager.getSubscription().then(function(subscription) {
    //   console.log("got subscription id: ", subscription.endpoint)
    // });
    try {
      var selfRegistration = _context['self']['registration'];
      var pushManager = selfRegistration["pushManager"];
      var jsSubscription = await jsPromiseToFuture(
          pushManager.callMethod("getSubscription"));

      var subscription = new PushSubscription(jsSubscription);
      return new Optional.of(subscription);
    } catch (e) {
      return new Optional.absent();
    }
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

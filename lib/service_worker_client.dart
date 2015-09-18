library service_worker_client;

import 'dart:js' as js;
import 'dart:async';

import 'src/promise.dart';
import 'src/utils.dart';

class PermissionDeniedError extends Error {
  final String message;
  PermissionDeniedError(this.message);

  toString() => "PermissionDeniedError: $message";
}

class PushSubscription {
  final js.JsObject object;

  PushSubscription(this.object);

  String get endpoint {
    String endpoint = object['endpoint'];

    // Make sure we only mess with GCM
    if (!endpoint.startsWith('https://android.googleapis.com/gcm/send')) {
      return endpoint;
    }

    if (object.hasProperty("subscriptionId")) {
      String subscriptionId = object["subscriptionId"];
      // Chrome 42 + 43 will not have the subscriptionId attached
      // to the endpoint.
      if (!endpoint.contains(subscriptionId)) {
        endpoint = endpoint + "/" + subscriptionId;
      }
    }
    return endpoint;
  }

  String get subscriptionId {
    return endpoint.split("/").last;
  }

  toString() => "Subscription<...${subscriptionId.substring((subscriptionId.length * 3 / 4).round())}>";
}

abstract class ServiceWorkerClientHelper {
  final js.JsObject _context;

  bool _isPushEnabled = false;
  bool get isPushEnabled => _isPushEnabled;

  ServiceWorkerClientHelper([js.JsObject context])
      : _context = context != null ? context : js.context;

  Future init({String serviceWorkerUrl: "./service-worker.js",
      String scope: "./"}) async {
    onBeforeInit();
    try {
      await registerServiceWorker(serviceWorkerUrl, scope: scope);
      await initialisePushMessageState();
      onInitSuccess();
    } on PermissionDeniedError catch (e) {
      onPushMessagePermissionDeniedError(e);
    } catch (e) {
      onInitFailure(e);
    }
    return new Future.value();
  }

  Future _getServiceWorkerRegistration() =>
      jsPromiseToFuture(_context["navigator"]["serviceWorker"]["ready"]);

  bool get _isNotificationPermissionDenied =>
      _context["Notification"]["permission"] == "denied";

  Future _getSubscriptionFromSWRegistration(serviceWorkerRegistration) =>
      jsPromiseToFuture(serviceWorkerRegistration['pushManager']
          .callMethod("getSubscription"));

  Future initialisePushMessageState() async {
    // Are Notifications supported in the service worker?
    if (!(_context['ServiceWorkerRegistration']['prototype'] as js.JsObject)
        .hasProperty("showNotification")) {
      throw new UnimplementedError("Notifications aren't supported.");
    }

    // Check the current Notification permission.
    // If its denied, it's a permanent block until the
    // user changes the permission
    if (_isNotificationPermissionDenied) {
      throw new PermissionDeniedError("Notification");
    }

    // Check if push messaging is supported
    if (!(_context.hasProperty("PushManager"))) {
      throw new UnimplementedError("Push messaging isn't supported.");
    }

    // We need the service worker registration to check for a subscription
    var serviceWorkerRegistration = await _getServiceWorkerRegistration();

    // Do we already have a push message subscription?
    var subscription =
        await _getSubscriptionFromSWRegistration(serviceWorkerRegistration);

    if (subscription == null) {
      // We aren’t subscribed to push, so set UI
      // to allow the user to enable push
      onPushMessageNoSubscription();
      return new Future.value();
    }

    // We are subscribed and push-enabled.
    _isPushEnabled = true;
    var wrappedSubscription = new PushSubscription(subscription);
    onPushMessageSubscription(wrappedSubscription);
    return wrappedSubscription;
  }

  void onBeforeInit();
  void onInitSuccess();
  void onInitFailure(Error e);
  void onPushMessageNoSubscription();
  void onPushMessagePermissionDeniedError(PermissionDeniedError e);
  /// Fired when [subscription] is extracted from Service Worker.
  void onPushMessageSubscription(PushSubscription subscription);
  void onPushMessageUnsubscribe(PushSubscription subscription, bool success);
  void onPushMessageSubscribe(PushSubscription subscription);

  Future registerServiceWorker(String url, {String scope}) {
    if (!(_context['navigator'] as js.JsObject).hasProperty("serviceWorker")) {
      throw new UnimplementedError("Service Worker isn't supported.");
    }
    var opts = createJsOptionsMap({"scope": scope});
    js.JsObject serviceWorker = _context['navigator']['serviceWorker'];
    return jsPromiseToFuture(serviceWorker.callMethod("register", [url, opts]));
  }

  Future subscribe() async {
    var serviceWorkerRegistration = await _getServiceWorkerRegistration();
    var pushManager = serviceWorkerRegistration['pushManager'];
    var opts = createJsOptionsMap({"userVisibleOnly": true});
    try {
      var subscription =
          await jsPromiseToFuture(pushManager.callMethod("subscribe", [opts]));
      _isPushEnabled = true;
      var wrappedSubscription = new PushSubscription(subscription);
      onPushMessageSubscribe(wrappedSubscription);
      onPushMessageSubscription(wrappedSubscription);
      return wrappedSubscription;
    } catch (e) {
      if (_isNotificationPermissionDenied) {
        onPushMessagePermissionDeniedError(e);
      } else {
        throw e;
      }
    }
  }

  Future unsubscribe() async {
    var serviceWorkerRegistration = await _getServiceWorkerRegistration();
    // To unsubscribe from push messaging, you need get the
    // subcription object, which you can call unsubscribe() on.
    var subscription =
        await _getSubscriptionFromSWRegistration(serviceWorkerRegistration);

    if (subscription == null) {
      throw new StateError(
          "Tried to unsubscribe when there was no subscription.");
    }
    var wrappedSubscription = new PushSubscription(subscription);

    var successful =
        await jsPromiseToFuture(subscription.callMethod("unsubscribe"));

    _isPushEnabled = false;
    onPushMessageUnsubscribe(wrappedSubscription, successful);
  }
}

library service_worker_client;

import 'dart:js' as js;
import 'dart:async';

import 'package:quiver/core.dart';

import 'package:dart_service_worker/src/promise.dart';
import 'package:dart_service_worker/src/js_interop_utils.dart';
import 'package:dart_service_worker/src/errors.dart';
export 'package:dart_service_worker/src/errors.dart';
import 'package:dart_service_worker/src/push_subscription.dart';

class ServiceWorkerManager {
  final js.JsObject _context;

  ServiceWorkerManager([js.JsObject context])
      : _context = context != null ? context : js.context;

  bool _isPushEnabled = false;
  bool get isPushEnabled => _isPushEnabled;

  _assertServiceWorkerSupportOrThrow() {
    if (!(_context['navigator'] as js.JsObject).hasProperty("serviceWorker")) {
      throw new UnsupportedFeatureError("Service Worker isn't supported.");
    }
  }

  /// Registers the Service Worker at [url] with [scope].
  ///
  /// Throws an [UnsupportedFeatureError] if Service Worker isn't supported.
  Future registerServiceWorker(
      {String url: "./service-worker.js", String scope: "./"}) async {
    _assertServiceWorkerSupportOrThrow();
    var opts = createJsOptionsMap({"scope": scope});
    js.JsObject serviceWorker = _context['navigator']['serviceWorker'];
    try {
      var result = await jsPromiseToFuture(serviceWorker.callMethod("register",
          [url, opts]));
      return result;
    } catch (e) {
      throw wrapServiceWorkerError(e, "Error when registering Service Worker"
          " at $url");
    }
  }

  Future _getServiceWorkerRegistration() =>
      jsPromiseToFuture(_context["navigator"]["serviceWorker"]["ready"]);

  bool get _isNotificationPermissionDenied =>
      _context["Notification"]["permission"] == "denied";

  Future _getSubscriptionFromSWRegistration(serviceWorkerRegistration) =>
      jsPromiseToFuture(serviceWorkerRegistration['pushManager']
          .callMethod("getSubscription"));

  /// Returns an [Optional] of [PushSubscription].
  ///
  /// If the return value is [Optional.isAbsent], you can always
  /// [createPushSubscription].
  ///
  /// Throws an [UnsupportedFeatureError] if either of Notifications or Push
  /// Messaging isn't supported. Throws an [PermissionDeniedError] if
  /// the user has denied notifications for the app.
  Future<Optional<PushSubscription>> getCurrentPushSubscription() async {
    _assertServiceWorkerSupportOrThrow();
    // Are Notifications supported in the service worker?
    if (!(_context['ServiceWorkerRegistration']['prototype'] as js.JsObject)
        .hasProperty("showNotification")) {
      throw new UnsupportedFeatureError("Notifications aren't supported.");
    }

    // Check the current Notification permission.
    // If its denied, it's a permanent block until the
    // user changes the permission
    if (_isNotificationPermissionDenied) {
      throw new PermissionDeniedError("Notification");
    }

    // Check if push messaging is supported
    if (!(_context.hasProperty("PushManager"))) {
      throw new UnsupportedFeatureError("Push messaging isn't supported.");
    }

    // We need the service worker registration to check for a subscription
    var serviceWorkerRegistration = await _getServiceWorkerRegistration();

    // Do we already have a push message subscription?
    var subscription =
        await _getSubscriptionFromSWRegistration(serviceWorkerRegistration);

    if (subscription == null) {
      // We aren’t subscribed to push.
      return const Optional.absent();
    }

    // We are subscribed and push-enabled.
    _isPushEnabled = true;
    var wrappedSubscription = new PushSubscription(subscription);
    return new Optional.of(wrappedSubscription);
  }

  /// Subscribes to Push Messages for notification purposes.
  ///
  /// Returns the [PushSubscription].
  ///
  /// Throws an [PermissionDeniedError] if Notifications are denied by user.
  /// Can also throw when the call to [:subscribe():] on [:pushManager:]
  /// fails.
  Future<PushSubscription> createPushSubscription(
      {bool userVisibleOnly: true}) async {
    if (!userVisibleOnly) {
      throw new UnsupportedError("userVisibleOnly must currently be always "
          "true.");
    }
    var serviceWorkerRegistration = await _getServiceWorkerRegistration();
    var pushManager = serviceWorkerRegistration['pushManager'];
    var opts = createJsOptionsMap({"userVisibleOnly": userVisibleOnly});
    try {
      var subscription =
          await jsPromiseToFuture(pushManager.callMethod("subscribe", [opts]));
      _isPushEnabled = true;
      var wrappedSubscription = new PushSubscription(subscription);
      return wrappedSubscription;
    } catch (e) {
      _isPushEnabled = false;
      if (_isNotificationPermissionDenied) {
        throw new PermissionDeniedError("Can't create new push subscription"
            " when notification is denied. \n$e");
      } else {
        throw wrapServiceWorkerError(e);
      }
    }
  }

  /// Unsubscribes from the (singleton) Push Message subscription.
  ///
  /// Returns an [Optional] of the [PushSubscription] we unsubscribed from.
  Future<Optional<PushSubscription>> removePushSubscription() async {
    var optionalSubscription = await getCurrentPushSubscription();

    if (!optionalSubscription.isPresent) {
      _isPushEnabled = false;
      return optionalSubscription;
    }

    bool successful = await optionalSubscription.value.unsubscribe();
    if (successful) {
      _isPushEnabled = false;
    }
    return optionalSubscription;
  }
}

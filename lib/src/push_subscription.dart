library push_subscription;

import 'dart:async';
import 'dart:js' as js;

import 'package:dart_service_worker/src/promise.dart';

class PushSubscription {
  final js.JsObject jsObject;

  PushSubscription(this.jsObject) {
    if (jsObject == null) {
      throw new ArgumentError("Provided PushSubscription JS object cannot "
          "be null.");
    }
  }

  String get endpoint {
    if (!jsObject.hasProperty("endpoint")) {
      throw new StateError("PushSubscription has null endpoint");
    }

    String endpoint = jsObject['endpoint'];

    // Make sure we only mess with GCM
    if (!endpoint.startsWith('https://android.googleapis.com/gcm/send')) {
      return endpoint;
    }

    if (jsObject.hasProperty("subscriptionId")) {
      String subscriptionId = jsObject["subscriptionId"];
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

  Future unsubscribe() {
    return jsPromiseToFuture(jsObject.callMethod("unsubscribe"));
  }

  toString() =>
      "Subscription<...${subscriptionId.substring((subscriptionId.length * 3 / 4).round())}>";
}
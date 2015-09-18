import 'dart:async';

import 'package:dart_service_worker/service_worker_helper.dart';
import 'package:dart_service_worker/config.dart';

// TODO: change
const String CANONICAL_URL = "https://filip-app.appspot.com/";

class PushMessage {
  final String message;
  PushMessage(this.message);
  PushMessage.fromMap(Map o) : this(o['message']);
}

class MyHelper extends ServiceWorkerHelper {
  @override
  Future onPushMessage(event) async {
    final contents = await fetchJson(FIREBASE_LATEST_MESSAGE_JSON);
    final message = new PushMessage.fromMap(contents);

    // TODO: close old notifications

    return showNotification(message.message, "To teď řekl Filip.",
        "/images/filip-192x192.png",
        "filip-app-notification-tag");
  }

  @override
  Future onNotificationClick(event) async {
    var clientsList = await clients.matchAll(type: MatchType.WINDOW);
    var matching = clientsList.where((c) => c.url == CANONICAL_URL);
    if (matching.isNotEmpty) {
      return matching.first.focus();
    } else {
      return clients.openWindow(CANONICAL_URL);
    }
  }
}

main() {
  new MyHelper().run();
}

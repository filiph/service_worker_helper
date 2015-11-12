// Copyright (c) 2015, Filip Hracek. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:html';
import 'dart:async';
import 'dart:js';

import 'package:firebase/firebase.dart';

import 'package:dart_service_worker/config.dart';
import 'package:dart_service_worker/service_worker_manager.dart';

class MaterialSwitch {
  final JsObject jsObject;
  MaterialSwitch(this.jsObject);

  void on() => jsObject.callMethod("on");
  void off() => jsObject.callMethod("off");

  bool get checked => jsObject['inputElement_']['checked'];
}

class KsichtApp {
  CheckboxInputElement pushPermissionSwitchEl;
  MaterialSwitch pushPermissionSwitch;
  Element filipMessageEl;
  Element filipMessageBubbleEl;
  Element subsPermissionDeniedEl;
  ParagraphElement subsCountMessageEl;
  Firebase fb;

  void updatePushPermissionSwitch() {
    if (pushPermissionSwitch == null) {
      // Switch not yet upgraded to Material Design.
      pushPermissionSwitchEl.checked = _sw.isPushEnabled;
      return;
    }
    if (_sw.isPushEnabled) {
      pushPermissionSwitch.on();
    } else {
      pushPermissionSwitch.off();
    }
  }

  void _hideElement(Element el) {
    el.style.display = "none";
  }

  void _showElement(Element el) {
    el.style.display = "block";
  }

  Future handlePushPermissionSwitchClick(_) async {
    if (!_sw.isPushEnabled) {
      // TODO: dim screen as per guidelines
      try {
        var sub = await _sw.createPushSubscription();
        onPushMessageSubscribe(sub);
      } on PermissionDeniedError catch (e) {
        onPushMessagePermissionDeniedError(e);
      } catch (e) {
        print("Something went wrong: $e");  // TODO: show to user?
      }
      updatePushPermissionSwitch();
    } else {
      var optionalSubscription = await _sw.removePushSubscription();
      optionalSubscription.ifPresent((sub) {
        onPushMessageUnsubscribe(sub);
      });
      updatePushPermissionSwitch();
    }
  }

  Firebase get _subscriptionSet => fb.child(FIREBASE_SUBSCRIPTION_SET);
  Firebase get _subscriptionsCount => fb.child(FIREBASE_SUBSCRIPTIONS_COUNT);
  Firebase get _filipMessage => fb.child(FIREBASE_LATEST_MESSAGE);

  void _updateSubscriptionsCount(int change) {
    _subscriptionsCount.transaction((currentVal) {
      return (currentVal == null ? 0 : currentVal) + change;
    });
  }

  final ServiceWorkerManager _sw = new ServiceWorkerManager();

  getDomElements() {
    pushPermissionSwitchEl = querySelector("#push-permission-switch");
    filipMessageEl = querySelector("#filip-message");
    filipMessageBubbleEl = querySelector("#filip-message-bubble");
    subsPermissionDeniedEl =
        querySelector("#push-subscription-permission-denied");
    subsCountMessageEl = querySelector("#subscriptions-count-message");
  }

  init() async {
    fb = new Firebase(FIREBASE_URL);
    getDomElements();

    try {
      await _sw.registerServiceWorker();
      var sub = await _sw.getCurrentPushSubscription();
      if (sub.isPresent) {
        print("We have a subscription.");
      } else {
        print("There's currently no subscription.");
      }
      onInitDone();
    } on PermissionDeniedError catch (e) {
      onPushMessagePermissionDeniedError(e);
      onInitDone();
    } catch (e) {
      onInitFailure(e);
    }
  }

  String _createSubsCountMessage(int count) {
    if (count == null || count <= 0) {
      return "(Filipa teď nikdo neposlouchá)";
    } else if (count == 1) {
      return "(Filipa teď poslouchá jeden člověk)";
    } else if (count <= 4) {
      return "(Filipa teď poslouchají $count lidé)";
    } else {
      return "(Filipa teď poslouchá $count lidí)";
    }
  }

  void _startFirebaseListeners() {
    _subscriptionsCount.onValue.listen((event) {
      int count = event.snapshot.val();
      subsCountMessageEl.text = _createSubsCountMessage(count);
    });

    _filipMessage.onValue.listen((event) {
      String msg = event.snapshot.val()["message"];
      filipMessageEl.text = msg == null ? "<teď zrovna nic>" : msg;
      filipMessageBubbleEl.classes.add("expanded");
    });
  }

  void _upgradeSwitch() {
    pushPermissionSwitch = new MaterialSwitch(
        new JsObject(context['MaterialSwitch'], [querySelector(".mdl-switch")])
    );
  }

  void onInitDone() {
    updatePushPermissionSwitch();
    pushPermissionSwitchEl.disabled = false;
    pushPermissionSwitchEl.onChange.listen((handlePushPermissionSwitchClick));

    _startFirebaseListeners();
    _upgradeSwitch();
  }

  void onInitFailure(Error e) {
    _showElement(querySelector("#unimplemented-error"));
    print("Service Worker failed to initialize.");
    print(e);

    _startFirebaseListeners();
    _upgradeSwitch();
  }

  void onPushMessagePermissionDeniedError(_) {
    _showElement(subsPermissionDeniedEl);
  }

  onPushMessageSubscribe(PushSubscription subscription) async {
    _hideElement(subsPermissionDeniedEl);
    var subFirebaseRec = _subscriptionSet.child(subscription.subscriptionId);
    var snapshot = await subFirebaseRec.once("value");
    if (!snapshot.exists) {
      subFirebaseRec.set(true);
      _updateSubscriptionsCount(1);
    }
  }

  onPushMessageUnsubscribe(PushSubscription subscription) async {
    _hideElement(subsPermissionDeniedEl);
    // Even in case of failure, remove subscription from server.
    var subFirebaseRec = _subscriptionSet.child(subscription.subscriptionId);
    var snapshot = await subFirebaseRec.once("value");
    if (snapshot.exists) {
      subFirebaseRec.set(null);
      _updateSubscriptionsCount(-1);
    }
  }
}

void main() {
  // Start app
  new KsichtApp().init();
}

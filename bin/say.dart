#!/usr/bin/env dart

import "dart:async";

import "package:console/console.dart";
import 'package:firebase/firebase_io.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:dart_service_worker/config.dart';

void replaceLine(String s) {
  Console.overwriteLine(" " * Console.columns);
  Console.overwriteLine(s);
}

Future main(List<String> args) async {
  Console.init();

  if (args.isEmpty) {
    print("Please provide a message.");
    return;
  }

  replaceLine("Initializing.");
  var fb = new FirebaseClient.anonymous();

  replaceLine("Contacting server.");
  Map subsMap = await fb.get(Uri.parse("$FIREBASE_URL/subscriptionSet.json"));
  var subs = subsMap.keys.toList(growable: false);

  replaceLine("Got ${subs.length} subscriptions. Updating count.");
  await fb.put(Uri.parse("$FIREBASE_URL/subscriptionsCount.json"), subs.length);

  replaceLine("Updating message.");
  var msgPayload = {"message": args.join(" ")};
  await fb.put(Uri.parse("$FIREBASE_URL/latestMessage.json"), msgPayload);

  replaceLine("Contacting GCM server.");
  var payload = {"registration_ids": subs};
  var json = JSON.encode(payload);
  var resp = await http.post(GCM_ENDPOINT, headers: {
    "Authorization": "key=$API_KEY",
    "Content-Type": "application/json"
  }, body: json);
  Map respMap = JSON.decode(resp.body);
  replaceLine("");
  Console.write("GCM: ");
  Console.setTextColor(2);
  Console.write(respMap["success"].toString());
  Console.resetTextColor();
  Console.write(" success, ");
  Console.setTextColor(1);
  Console.write(respMap["failure"].toString());
  Console.resetTextColor();
  Console.write(" failure");

  Console.setTextColor(2);
  Console.setBold(true);
  Console.write("\nDone.");
  Console.setBold(false);
  Console.resetAll();
  print("");
}
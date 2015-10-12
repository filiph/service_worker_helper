import 'dart:async';

import 'package:path/path.dart' as path;
import 'package:barback/barback.dart';
import 'package:uuid/uuid.dart';

class ServiceWorkerJavaScriptTransformer extends Transformer
    implements DeclaringTransformer {
  ServiceWorkerJavaScriptTransformer.asPlugin();

  Future<bool> isPrimary(AssetId id) {
    return new Future.value(id.path.endsWith("service-worker.dart"));
  }

  String _produceServiceWorkerJavaScriptFile() {
    String hash = uuid.v1();
    return JAVASCRIPT_TEMPLATE.replaceFirst("[[SALT]]", hash);
  }

  Future apply(Transform transform) async {
    // Copy service-worker.dart verbatim.
    var primaryId = transform.primaryInput.id;
    transform.addOutput(
        new Asset.fromStream(primaryId, transform.primaryInput.read()));
    // Create the js file.
    var jsId = primaryId.changeExtension(".js");
    var content = _produceServiceWorkerJavaScriptFile();
    transform.addOutput(new Asset.fromString(jsId, content));
  }

  @override
  declareOutputs(DeclaringTransform transform) {
    var primaryId = transform.primaryId;
    transform.declareOutput(primaryId);
    var jsId = primaryId.changeExtension(".js");
    transform.declareOutput(jsId);
  }

  final uuid = new Uuid();

  static const String JAVASCRIPT_TEMPLATE = """
'use strict';

// Browsers don't detect changes in imported scripts.
// Adding a new salt for each time this is generated.
// Salt: [[SALT]]
importScripts("service-worker.dart.js");

self.addEventListener('push', function(event) {
  event.waitUntil(dartExportedHandlePushMessage(event));
});

self.addEventListener('notificationclick', function(event) {
  // Android doesn’t close the notification when you click on it
  // See: http://crbug.com/463146
  event.notification.close();
  event.waitUntil(dartExportedHandleNotificationClick(event));
});
  """;
}

class ConcatTransformer extends AggregateTransformer {
  ConcatTransformer.asPlugin();

  classifyPrimary(AssetId id) {
    if (!id.path.endsWith('.html') && !id.path.endsWith('.js')) return null;

    return path.url.dirname(id.path);
  }

  static const String CONCAT_START = "<!-- #dart_concat -->";
  static const String CONCAT_END = "<!-- #end_dart_concat -->";

  Future apply(AggregateTransform transform) async {
    var htmlAssets = new Set<Asset>();
    var jsAssets = new Set<Asset>();
    await for (Asset input in transform.primaryInputs) {
      if (input.id.extension == ".html") htmlAssets.add(input);
      else if (input.id.extension == ".js") jsAssets.add(input);
    }

    for (var htmlAsset in htmlAssets) {
      var html = await htmlAsset.readAsString();

      // TODO: allow more than one per file
      int start = html.indexOf(CONCAT_START);
      int end = html.indexOf(CONCAT_END);

      if (start == -1 || end == -1) {
        // No concat.
        transform
            .addOutput(new Asset.fromStream(htmlAsset.id, htmlAsset.read()));
        continue;
      }

      var uid = uuid.v1();
      var combinedId = htmlAsset.id.changeExtension(".$uid.js");
      var combinedUrl = path.basename(combinedId.path);

      var htmlBuffer = new StringBuffer();
      htmlBuffer.write(html.substring(0, start + CONCAT_START.length));
      htmlBuffer.write("<script defer src=\"$combinedUrl\"></script>");
      htmlBuffer.write(html.substring(end + CONCAT_END.length));
      transform
          .addOutput(new Asset.fromString(htmlAsset.id, htmlBuffer.toString()));

      var scriptAssets = new List<Asset>();
      var scriptsContent = html.substring(start + CONCAT_START.length, end);
      _scriptTagMatch.allMatches(scriptsContent).forEach((match) {
        var tag = match.group(0);
        var srcMatch = _srcInTagMatch.allMatches(tag).single;
        var src =
            srcMatch.group(2) != null ? srcMatch.group(2) : srcMatch.group(3);
        assert(src != null);
        var canonicalPath = path.url.join(transform.key, src);
//        print("-- ${htmlAsset.id.path} -- ");
//        print("'$canonicalPath'");
//        jsAssets.forEach((a) => print("'${a.id.path}'"));
        var asset = jsAssets.where((a) => a.id.path == canonicalPath).single;
        scriptAssets.add(asset);
      });

      var jsBuffer = new StringBuffer();
      for (var asset in scriptAssets) {
        var content = await asset.readAsString();
        jsBuffer.write(content);
      }

      transform
          .addOutput(new Asset.fromString(combinedId, jsBuffer.toString()));
    }
  }

  static final RegExp _scriptTagMatch = new RegExp(r"<\s*script.*?></script>");
  static final RegExp _srcInTagMatch = new RegExp(r"""src=('(.+?)'|"(.+?)")""");

  final uuid = new Uuid();
}

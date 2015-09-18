part of service_worker_helper;

class Client {
  final js.JsObject object;

  Client(this.object);

  String get url => object['url'];

  String get id => object['id'];
  Object get visibilityState => object['visibilityState'];

  bool get focused => object['focused'];

  Future focus() {
    if (!object.hasProperty("focus")) {
      throw new UnimplementedError("Client.focus() not implemented.");
    }
    return jsPromiseToFuture(object.callMethod("focus"));
  }

  Future navigate(String url) {
    if (!object.hasProperty("navigate")) {
      throw new UnimplementedError("Client.navigate() not implemented.");
    }
    return jsPromiseToFuture(object.callMethod("navigate", [url]));
  }

  void postMessage(message, transfer) => throw new UnimplementedError();
}

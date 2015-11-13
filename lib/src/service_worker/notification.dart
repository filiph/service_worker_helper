part of service_worker_helper;

class Notification {
  final js.JsObject object;

  Notification(this.object);

  void close() {
    object.callMethod("close");
  }
}

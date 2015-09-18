part of service_worker_helper;

class Clients {
  final js.JsObject object;

  Clients(this.object);

  Future<List<Client>> matchAll(
      {bool includeUncontrolled, MatchType type}) async {
    var opts = createJsOptionsMap({
      'includeUncontrolled': includeUncontrolled,
      'type': type != null ? _matchTypeEnumToString(type) : null
    });

    js.JsObject clients =
        await jsPromiseToFuture(object.callMethod("matchAll", [opts]));
    int length = clients['length'];
    List<Client> result = new List<Client>(length);
    for (int i = 0; i < length; i++) {
      result[i] = new Client(clients[i]);
    }
    return result;
  }

  Future openWindow(String url) =>
      jsPromiseToFuture(object.callMethod("openWindow", [url]));

  Future claim() => jsPromiseToFuture(object.callMethod("claim"));
}

enum MatchType { WINDOW, WORKER, SHAREDWORKER, ALL }

String _matchTypeEnumToString(MatchType type) {
  switch (type) {
    case MatchType.WINDOW:
      return "window";
    case MatchType.WORKER:
      return "worker";
    case MatchType.SHAREDWORKER:
      return "sharedworker";
    case MatchType.ALL:
      return "all";
  }
}

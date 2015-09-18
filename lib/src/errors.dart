library service_worker_errors;


class PermissionDeniedError extends Error {
  final String message;
  PermissionDeniedError(this.message);

  toString() => "PermissionDeniedError: $message";
}

class NetworkError extends Error {
  final String message;
  NetworkError(this.message);

  toString() => "NetworkError: $message";
}

class JsonParseError extends Error {
  final String message;
  JsonParseError(this.message);

  toString() => "JsonParseError: $message";
}

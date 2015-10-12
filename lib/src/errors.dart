library service_worker_errors;


RegExp FIRST_WORD_RE = new RegExp(r"^\w+");

/// Takes the JavaScript error object and wraps it in a nice Dart-y [Error].
Error wrapServiceWorkerError(Object e, [String customMessage]) {
  String errorString;
  try {
    errorString = "$e";
  } catch (_) {
    return new UnknownError("Couldn't distinguish the error.");
  }

  String firstString = FIRST_WORD_RE.firstMatch(errorString).group(0);
  String errorMessage;
  if (firstString.length + 2 < errorString.length) {
    errorMessage = errorString.substring(firstString.length + 2);
  } else {
    errorMessage = errorString;
  }

  if (customMessage != null) {
    errorMessage = "$customMessage ($errorMessage)";
  }

  switch(firstString) {
    case "InstallError":
      return new InstallError(errorMessage);
    case "AbortError":
      return new AbortError(errorMessage);
    case "NotSupportedError":
      return new NotSupportedError(errorMessage);
    case "AbortError":
      return new AbortError(errorMessage);
    case "NetworkError":
      return new NetworkError(errorMessage);
    case "NotFoundError":
      return new NotFoundError(errorMessage);
    case "SecurityError":
      return new SecurityError(errorMessage);
    case "InvalidStateError":
      return new InvalidStateError(errorMessage);
    case "AbortError":
      return new AbortError(errorMessage);
    case "UnknownError":
      return new UnknownError(errorMessage);
    default:
      return new UnknownError(errorMessage);
  }
}

// Custom Errors

class PermissionDeniedError extends Error {
  final String message;
  PermissionDeniedError(this.message);

  toString() => "PermissionDeniedError: $message";
}

class UnsupportedFeatureError extends Error {
  final String message;
  UnsupportedFeatureError(this.message);

  toString() => "UnsupportedFeatureError: $message";
}

class JsonParseError extends Error {
  final String message;
  JsonParseError(this.message);

  toString() => "JsonParseError: $message";
}

// Taken from:
// https://chromium.googlesource.com/experimental/chromium/blink/+/master/Source/modules/serviceworkers/ServiceWorkerError.cpp

class NetworkError extends Error {
  final String message;
  NetworkError(this.message);

  toString() => "NetworkError: $message";
}

class InstallError extends Error {
  final String message;
  InstallError(this.message);

  toString() => "InstallError: $message";
}

class AbortError extends Error {
  final String message;
  AbortError(this.message);

  toString() => "AbortError: $message";
}

class NotSupportedError extends Error {
  final String message;
  NotSupportedError(this.message);

  toString() => "NotSupportedError: $message";
}

class NotFoundError extends Error {
  final String message;
  NotFoundError(this.message);

  toString() => "NotFoundError: $message";
}

class SecurityError extends Error {
  final String message;
  SecurityError(this.message);

  toString() => "SecurityError: $message";
}

class InvalidStateError extends Error {
  final String message;
  InvalidStateError(this.message);

  toString() => "InvalidStateError: $message";
}

class UnknownError extends Error {
  final String message;
  UnknownError(this.message);

  toString() => "UnknownError: $message";
}

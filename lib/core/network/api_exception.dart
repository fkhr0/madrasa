/// A request that failed, with a message ready to show to the user.
class ApiException implements Exception {
  final String message;

  /// HTTP status, or 0 when the server couldn't be reached.
  final int status;

  const ApiException(this.message, {this.status = 0});

  bool get isOffline => status == 0;

  @override
  String toString() => message;
}

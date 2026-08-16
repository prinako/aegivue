class ApiException implements Exception {
  const ApiException(this.statusCode, [this.message, this.cause]);

  final int? statusCode;
  final String? message;
  final Object? cause;

  @override
  String toString() {
    if (message != null) return message!;
    if (statusCode != null) return 'Request failed with status $statusCode';
    return 'Unable to reach the server';
  }
}

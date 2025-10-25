class HttpException implements Exception {
  final String message;
  final int statusCode;

  const HttpException(this.statusCode, this.message);

  @override
  String toString() {
    return 'HttpException(statusCode: $statusCode, message: $message)';
  }

  factory HttpException.notFound(String message) {
    return HttpException(404, message);
  }

  factory HttpException.unauthorized(String message) {
    return HttpException(401, message);
  }

  factory HttpException.forbidden(String message) {
    return HttpException(403, message);
  }

  factory HttpException.badRequest(String message) {
    return HttpException(400, message);
  }

  factory HttpException.internalServerError(String message) {
    return HttpException(500, message);
  }

  factory HttpException.validationError(String message) {
    return HttpException(422, message);
  }

  factory HttpException.conflict(String message) {
    return HttpException(409, message);
  }

  factory HttpException.serviceUnavailable(String message) {
    return HttpException(503, message);
  }

  factory HttpException.unprocessableEntity(String message) {
    return HttpException(422, message);
  }

  factory HttpException.methodNotAllowed(String message) {
    return HttpException(405, message);
  }

  factory HttpException.unsupportedMediaType(String message) {
    return HttpException(415, message);
  }
}

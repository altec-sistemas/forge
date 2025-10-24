import 'dart:convert';

import 'package:shelf/shelf.dart';

class JsonResponse extends Response {
  final Object? data;

  JsonResponse(this.data, {int statusCode = 200, Map<String, String>? headers})
    : super(
        statusCode,
        headers: {'Content-Type': 'application/json'}..addAll(headers ?? {}),
        body: data is String ? data : jsonEncode(data),
      );
}

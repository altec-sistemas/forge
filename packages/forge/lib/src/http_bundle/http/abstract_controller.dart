import 'dart:async';

import '../../../forge.dart';

abstract class AbstractController {
  late final Serializer serializer;

  @Required()
  void setSerializer(Serializer serializer) {
    this.serializer = serializer;
  }

  Future<JsonResponse> json<T>(
    FutureOr<T> data, {
    int statusCode = 200,
    Map<String, String>? headers,
  }) async {
    final serializedData = serializer.serialize<T>(
      await data,
      'json',
    );

    return JsonResponse(
      serializedData,
      statusCode: statusCode,
      headers: headers,
    );
  }
}

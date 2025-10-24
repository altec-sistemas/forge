import '../../../forge.dart';

class RequestContext {
  Request request;

  RequestContext(this.request);

  void change({
    Map<String, /* String | List<String> */ Object?>? headers,
    Map<String, Object?>? context,
    String? path,
    Object? body,
  }) => request = request.change(
    headers: headers,
    context: context,
    path: path,
    body: body,
  );
}

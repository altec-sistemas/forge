import 'package:meta/meta_meta.dart';

import '../../forge.dart';

@Target({TargetKind.classType})
class Controller extends Service implements DeclarationsCapability {
  final String? prefix;

  const Controller({this.prefix, super.name, super.env, super.priority});
}

@Target({TargetKind.method})
class Route {
  final List<String> method;
  final String path;

  const Route(this.path, [this.method = const []]);

  const Route.get(this.path) : method = const ['GET'];
  const Route.post(this.path) : method = const ['POST'];
  const Route.put(this.path) : method = const ['PUT'];
  const Route.delete(this.path) : method = const ['DELETE'];
  const Route.patch(this.path) : method = const ['PATCH'];
  const Route.head(this.path) : method = const ['HEAD'];
  const Route.options(this.path) : method = const ['OPTIONS'];
}

@Target({TargetKind.parameter})
class QueryParam {
  final String? name;
  const QueryParam([this.name]);
}

@Target({TargetKind.parameter})
class MapRequestPayload {
  final bool validade;
  const MapRequestPayload([this.validade = true]);
}

@Target({TargetKind.parameter})
class MapRequestQuery {
  final bool validade;
  const MapRequestQuery([this.validade = true]);
}

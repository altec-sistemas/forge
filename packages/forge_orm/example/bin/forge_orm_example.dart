import 'package:forge_framework/forge_framework.dart';
import 'package:forge_orm/forge_orm.dart';
import 'package:forge_orm_example/src/app_bundle.dart';
import 'package:forge_orm_example/src/entity/user.dart';

void main() async {
  final forge = Kernel('dev')
    ..addBundle(OrmBundle())
    ..addBundle(AppBundle());
  await forge.run();
}

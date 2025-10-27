import 'package:forge_core/forge_core.dart';

import '../forge_orm.dart';
import 'orm_bundle.bundle.dart';

@AutoBundle(
  paths: ['lib/**.dart'],
  excludePaths: ['example/**.dart'],
)
class OrmBundle extends AbstractOrmBundle {}

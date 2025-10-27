import 'package:forge_framework/forge_framework.dart';
import 'package:forge_orm/forge_orm.dart';

@Mappable()
@Entity('users')
class User {
  @Column.id()
  int? id;
  @Column.varchar()
  String? name;
  @Column.varchar(unique: true)
  String? email;
}

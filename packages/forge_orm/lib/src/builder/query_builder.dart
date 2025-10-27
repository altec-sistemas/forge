import 'builder.dart';

class QueryBuilder extends Builder<QueryBuilder> {
  QueryBuilder(super.database);

  @override
  QueryBuilder createNew() {
    return QueryBuilder(database);
  }

  @override
  QueryBuilder get self => this;
}

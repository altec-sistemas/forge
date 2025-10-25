import 'package:forge_core/forge_core.dart';
import 'package:forge_core/metadata_compact_api.dart' as meta;

@Mappable()
class User {
  final String name;
  final int age;
  final String? email;
  final List<String>? tags;

  User(this.name, this.age, {this.email, this.tags});
}

@Mappable()
class Product {
  final String name;
  final double price;

  @Ignore()
  final String? internalCode;

  Product(this.name, this.price, {this.internalCode});
}

@Mappable()
class Order {
  @Property(name: 'order_id')
  final String orderId;

  @Property(groups: ['admin'])
  final double totalAmount;

  @Property(groups: ['public', 'admin'])
  final String status;

  Order(this.orderId, this.totalAmount, this.status);
}

@Mappable()
@EnumExtractor('value')
enum Priority {
  low('Low Priority'),
  medium('Medium Priority'),
  high('High Priority');

  final String value;
  const Priority(this.value);
}

@Mappable()
enum Status { active, inactive, pending }

@Mappable()
class Task {
  final String title;
  final Priority priority;

  @EnumDelimiter(',')
  final List<Status>? statuses;

  Task(this.title, this.priority, {this.statuses});
}

void buildMetadata(MetadataRegistryBuilder metaBuilder) {
  metaBuilder.registerClass<User>(
    meta.clazz(
      meta.type<User>(),
      const <Object>[Mappable()],
      [
        meta.constructor(
          () => User.new,
          [
            meta.parameter(
              meta.type<String>(),
              'name',
              0,
              false,
              false,
              null,
              const [],
            ),
            meta.parameter(
              meta.type<int>(),
              'age',
              1,
              false,
              false,
              null,
              const [],
            ),
            meta.parameter(
              meta.type<String>([], true),
              'email',
              2,
              true,
              true,
              null,
              const [],
            ),
            meta.parameter(
              meta.type<List<String>>([meta.type<String>()], true),
              'tags',
              3,
              true,
              true,
              null,
              const [],
            ),
          ],
          'new',
          const [],
        ),
      ],
      null, // methods
      [
        meta.getter(
          meta.type<String>(),
          'name',
          (instance) => instance.name,
          const [],
        ),
        meta.getter(
          meta.type<int>(),
          'age',
          (instance) => instance.age,
          const [],
        ),
        meta.getter(
          meta.type<String>([], true),
          'email',
          (instance) => instance.email,
          const [],
        ),
        meta.getter(
          meta.type<List<String>>([meta.type<String>()], true),
          'tags',
          (instance) => instance.tags,
          const [],
        ),
      ],
      null, // setters
    ),
  );

  metaBuilder.registerClass<Product>(
    meta.clazz(
      meta.type<Product>(),
      const <Object>[Mappable()],
      [
        meta.constructor(
          () => Product.new,
          [
            meta.parameter(
              meta.type<String>(),
              'name',
              0,
              false,
              false,
              null,
              const [],
            ),
            meta.parameter(
              meta.type<double>(),
              'price',
              1,
              false,
              false,
              null,
              const [],
            ),
            meta.parameter(
              meta.type<String>([], true),
              'internalCode',
              2,
              true,
              true,
              null,
              const [],
            ),
          ],
          'new',
          const [],
        ),
      ],
      null, // methods
      [
        meta.getter(
          meta.type<String>(),
          'name',
          (instance) => instance.name,
          const [],
        ),
        meta.getter(
          meta.type<double>(),
          'price',
          (instance) => instance.price,
          const [],
        ),
        meta.getter(
          meta.type<String>([], true),
          'internalCode',
          (instance) => instance.internalCode,
          const <Object>[Ignore()],
        ),
      ],
      null, // setters
    ),
  );

  metaBuilder.registerClass<Order>(
    meta.clazz(
      meta.type<Order>(),
      const <Object>[Mappable()],
      [
        meta.constructor(
          () => Order.new,
          [
            meta.parameter(
              meta.type<String>(),
              'orderId',
              0,
              false,
              false,
              null,
              const [],
            ),
            meta.parameter(
              meta.type<double>(),
              'totalAmount',
              1,
              false,
              false,
              null,
              const [],
            ),
            meta.parameter(
              meta.type<String>(),
              'status',
              2,
              false,
              false,
              null,
              const [],
            ),
          ],
          'new',
          const [],
        ),
      ],
      null, // methods
      [
        meta.getter(
          meta.type<String>(),
          'orderId',
          (instance) => instance.orderId,
          const <Object>[Property(name: 'order_id')],
        ),
        meta.getter(
          meta.type<double>(),
          'totalAmount',
          (instance) => instance.totalAmount,
          const <Object>[
            Property(groups: ['admin']),
          ],
        ),
        meta.getter(
          meta.type<String>(),
          'status',
          (instance) => instance.status,
          const <Object>[
            Property(groups: ['public', 'admin']),
          ],
        ),
      ],
      null, // setters
    ),
  );

  metaBuilder.registerClass<Task>(
    meta.clazz(
      meta.type<Task>(),
      const <Object>[Mappable()],
      [
        meta.constructor(
          () => Task.new,
          [
            meta.parameter(
              meta.type<String>(),
              'title',
              0,
              false,
              false,
              null,
              const [],
            ),
            meta.parameter(
              meta.type<Priority>(),
              'priority',
              1,
              false,
              false,
              null,
              const [],
            ),
            meta.parameter(
              meta.type<List<Status>>([meta.type<Status>()], true),
              'statuses',
              2,
              true,
              true,
              null,
              const [],
            ),
          ],
          'new',
          const [],
        ),
      ],
      null, // methods
      [
        meta.getter(
          meta.type<String>(),
          'title',
          (instance) => instance.title,
          const [],
        ),
        meta.getter(
          meta.type<Priority>(),
          'priority',
          (instance) => instance.priority,
          const [],
        ),
        meta.getter(
          meta.type<List<Status>>([meta.type<Status>()], true),
          'statuses',
          (instance) => instance.statuses,
          const <Object>[EnumDelimiter(',')],
        ),
      ],
      null, // setters
    ),
  );

  metaBuilder.registerEnum<Priority>(
    meta.enumMeta(
      meta.type<Priority>(),
      const <Object>[Mappable(), EnumExtractor('value')],
      [
        meta.enumValue('low', Priority.low, 0, const []),
        meta.enumValue('medium', Priority.medium, 1, const []),
        meta.enumValue('high', Priority.high, 2, const []),
      ],
      [
        meta.getter(
          meta.type<Priority>(),
          'low',
          (instance) => instance.low,
          const [],
        ),
        meta.getter(
          meta.type<Priority>(),
          'medium',
          (instance) => instance.medium,
          const [],
        ),
        meta.getter(
          meta.type<Priority>(),
          'high',
          (instance) => instance.high,
          const [],
        ),
        meta.getter(
          meta.type<List<Priority>>([meta.type<Priority>()]),
          'values',
          (instance) => instance.values,
          const [],
        ),
        meta.getter(
          meta.type<String>(),
          'value',
          (instance) => instance.value,
          const [],
        ),
      ],
    ),
  );

  metaBuilder.registerEnum<Status>(
    meta.enumMeta(
      meta.type<Status>(),
      const <Object>[Mappable()],
      [
        meta.enumValue('active', Status.active, 0, const []),
        meta.enumValue('inactive', Status.inactive, 1, const []),
        meta.enumValue('pending', Status.pending, 2, const []),
      ],
      [
        meta.getter(
          meta.type<Status>(),
          'active',
          (instance) => instance.active,
          const [],
        ),
        meta.getter(
          meta.type<Status>(),
          'inactive',
          (instance) => instance.inactive,
          const [],
        ),
        meta.getter(
          meta.type<Status>(),
          'pending',
          (instance) => instance.pending,
          const [],
        ),
        meta.getter(
          meta.type<List<Status>>([meta.type<Status>()]),
          'values',
          (instance) => instance.values,
          const [],
        ),
      ],
    ),
  );
}

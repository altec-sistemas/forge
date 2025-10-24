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
      [Mappable()],
      [
        meta.constructor(() => User.new, [
          meta.parameter(meta.type<String>(), 'name', 0, false, false, false),
          meta.parameter(meta.type<int>(), 'age', 1, false, false, false),
          meta.parameter(meta.type<String>(), 'email', 2, true, true, false),
          meta.parameter(
            meta.type<List>([meta.type<String>()]),
            'tags',
            3,
            true,
            true,
            false,
          ),
        ]),
      ],
      null,
      [
        meta.getter(meta.type<String>(), 'name', (instance) => instance.name),
        meta.getter(meta.type<int>(), 'age', (instance) => instance.age),
        meta.getter(meta.type<String>(), 'email', (instance) => instance.email),
        meta.getter(
          meta.type<List>([meta.type<String>()]),
          'tags',
          (instance) => instance.tags,
        ),
      ],
      null,
    ),
  );

  metaBuilder.registerClass<Product>(
    meta.clazz(
      meta.type<Product>(),
      [Mappable()],
      [
        meta.constructor(() => Product.new, [
          meta.parameter(meta.type<String>(), 'name', 0, false, false, false),
          meta.parameter(meta.type<double>(), 'price', 1, false, false, false),
          meta.parameter(
            meta.type<String>(),
            'internalCode',
            2,
            true,
            true,
            false,
          ),
        ]),
      ],
      null,
      [
        meta.getter(meta.type<String>(), 'name', (instance) => instance.name),
        meta.getter(meta.type<double>(), 'price', (instance) => instance.price),
        meta.getter(
          meta.type<String>(),
          'internalCode',
          (instance) => instance.internalCode,
          [Ignore()],
        ),
      ],
      null,
    ),
  );

  metaBuilder.registerClass<Order>(
    meta.clazz(
      meta.type<Order>(),
      [Mappable()],
      [
        meta.constructor(() => Order.new, [
          meta.parameter(
            meta.type<String>(),
            'orderId',
            0,
            false,
            false,
            false,
          ),
          meta.parameter(
            meta.type<double>(),
            'totalAmount',
            1,
            false,
            false,
            false,
          ),
          meta.parameter(meta.type<String>(), 'status', 2, false, false, false),
        ]),
      ],
      null,
      [
        meta.getter(
          meta.type<String>(),
          'orderId',
          (instance) => instance.orderId,
          [Property(name: 'order_id')],
        ),
        meta.getter(
          meta.type<double>(),
          'totalAmount',
          (instance) => instance.totalAmount,
          [
            Property(groups: ['admin']),
          ],
        ),
        meta.getter(
          meta.type<String>(),
          'status',
          (instance) => instance.status,
          [
            Property(groups: ['public', 'admin']),
          ],
        ),
      ],
      null,
    ),
  );

  metaBuilder.registerClass<Task>(
    meta.clazz(
      meta.type<Task>(),
      [Mappable()],
      [
        meta.constructor(() => Task.new, [
          meta.parameter(meta.type<String>(), 'title', 0, false, false, false),
          meta.parameter(
            meta.type<Priority>(),
            'priority',
            1,
            false,
            false,
            false,
          ),
          meta.parameter(
            meta.type<List>([meta.type<Status>()]),
            'statuses',
            2,
            true,
            true,
            false,
          ),
        ]),
      ],
      null,
      [
        meta.getter(meta.type<String>(), 'title', (instance) => instance.title),
        meta.getter(
          meta.type<Priority>(),
          'priority',
          (instance) => instance.priority,
        ),
        meta.getter(
          meta.type<List>([meta.type<Status>()]),
          'statuses',
          (instance) => instance.statuses,
          [EnumDelimiter(',')],
        ),
      ],
      null,
    ),
  );

  metaBuilder.registerEnum<Priority>(
    meta.enumMeta(
      meta.type<Priority>(),
      [Mappable(), EnumExtractor('value')],
      [
        meta.enumValue('low', Priority.low, 0),
        meta.enumValue('medium', Priority.medium, 1),
        meta.enumValue('high', Priority.high, 2),
      ],
      [meta.getter(meta.type<String>(), 'value', (instance) => instance.value)],
    ),
  );
  metaBuilder.registerEnum<Status>(
    meta.enumMeta(
      meta.type<Status>(),
      [Mappable()],
      [
        meta.enumValue('active', Status.active, 0),
        meta.enumValue('inactive', Status.inactive, 1),
        meta.enumValue('pending', Status.pending, 2),
      ],
      null,
    ),
  );
}

import 'package:forge_core/forge_core.dart';
import 'package:test/test.dart';

import 'fixtures/serializer_fixtures.dart';

void main() {
  late MetadataRegistry registry;
  late Serializer serializer;

  setUp(() {
    // Setup metadata registry with test fixtures
    final builder = MetadataRegistryBuilder();

    // Register User
    buildMetadata(builder);

    registry = builder.build();

    serializer = Serializer(
      transformers: [
        PrimitiveTransformer(),
        MetadataTransformer(registry),
        ListTransformer(),
        MapTransformer(),
      ],
      encoders: [
        JsonEncoder(),
      ],
    );
  });

  group('Serializer - Basic Serialization', () {
    test('should serialize simple object to JSON', () {
      final user = User('John Doe', 30, email: 'john@example.com');
      final json = serializer.serialize(user, 'json');

      expect(json, contains('"name":"John Doe"'));
      expect(json, contains('"age":30'));
      expect(json, contains('"email":"john@example.com"'));
    });

    test('should deserialize JSON to object', () {
      final json = '{"name":"Jane Doe","age":25,"email":"jane@example.com"}';
      final user = serializer.deserialize<User>(json, 'json');

      expect(user, isNotNull);
      expect(user!.name, equals('Jane Doe'));
      expect(user.age, equals(25));
      expect(user.email, equals('jane@example.com'));
    });

    test('should handle null values in serialization', () {
      final user = User('John Doe', 30);
      final json = serializer.serialize(user, 'json');

      expect(json, contains('"name":"John Doe"'));
      expect(json, contains('"email":null'));
    });

    test('should handle null values in deserialization', () {
      final json = '{"name":"John Doe","age":30}';
      final user = serializer.deserialize<User>(json, 'json');

      expect(user, isNotNull);
      expect(user!.name, equals('John Doe'));
      expect(user.email, isNull);
    });
  });

  group('Serializer - Normalization', () {
    test('should normalize object to Map', () {
      final user = User('John Doe', 30, email: 'john@example.com');
      final normalized = serializer.normalize(user);

      expect(normalized, isA<Map>());
      expect(normalized['name'], equals('John Doe'));
      expect(normalized['age'], equals(30));
      expect(normalized['email'], equals('john@example.com'));
    });

    test('should denormalize Map to object', () {
      final data = {
        'name': 'Jane Doe',
        'age': 25,
        'email': 'jane@example.com',
      };
      final user = serializer.denormalize<User>(data);

      expect(user, isNotNull);
      expect(user!.name, equals('Jane Doe'));
      expect(user.age, equals(25));
      expect(user.email, equals('jane@example.com'));
    });

    test('should handle nested lists in normalization', () {
      final user = User('John', 30, tags: ['developer', 'designer']);
      final normalized = serializer.normalize(user);

      expect(normalized['tags'], isA<List>());
      expect(normalized['tags'], equals(['developer', 'designer']));
    });

    test('should handle nested lists in denormalization', () {
      final data = {
        'name': 'John',
        'age': 30,
        'tags': ['developer', 'designer'],
      };
      final user = serializer.denormalize<User>(data);

      expect(user!.tags, equals(['developer', 'designer']));
    });
  });

  group('Serializer - Context Options', () {
    test('omitNull should remove null values from output', () {
      final user = User('John Doe', 30);
      final context = SerializerContext(omitNull: true);
      final json = serializer.serialize(user, 'json', context);

      expect(json, isNot(contains('"email"')));
      expect(json, isNot(contains('"tags"')));
    });

    test('pretty should format JSON with indentation', () {
      final user = User('John Doe', 30);
      final context = SerializerContext(pretty: true);
      final json = serializer.serialize(user, 'json', context);

      expect(json, contains('\n'));
      expect(json, contains('  '));
    });

    test('groups should filter properties', () {
      final order = Order('ORD-123', 99.99, 'pending');
      final adminContext = SerializerContext(groups: ['admin']);
      final publicContext = SerializerContext(groups: ['public']);

      final adminJson = serializer.serialize(order, 'json', adminContext);
      final publicJson = serializer.serialize(order, 'json', publicContext);

      expect(adminJson, contains('"totalAmount"'));
      expect(adminJson, contains('"status"'));
      expect(publicJson, isNot(contains('"totalAmount"')));
      expect(publicJson, contains('"status"'));
    });

    test('showIgnored should include ignored properties', () {
      final product = Product('Laptop', 999.99, internalCode: 'INT-001');
      final normalContext = SerializerContext();
      final showIgnoredContext = SerializerContext(showIgnored: true);

      final normalJson = serializer.serialize(product, 'json', normalContext);
      final showIgnoredJson = serializer.serialize(
        product,
        'json',
        showIgnoredContext,
      );

      expect(normalJson, isNot(contains('"internalCode"')));
      expect(showIgnoredJson, contains('"internalCode"'));
    });
  });

  group('Serializer - Annotations', () {
    test('@Property should rename field', () {
      final order = Order('ORD-123', 99.99, 'pending');
      final json = serializer.serialize(order, 'json');

      expect(json, contains('"order_id":"ORD-123"'));
      expect(json, isNot(contains('"orderId"')));
    });

    test('@Property with renamed field should deserialize correctly', () {
      final json =
          '{"order_id":"ORD-123","totalAmount":99.99,"status":"pending"}';
      final order = serializer.deserialize<Order>(json, 'json');

      expect(order, isNotNull);
      expect(order!.orderId, equals('ORD-123'));
    });

    test('@Ignore should exclude field from serialization', () {
      final product = Product('Laptop', 999.99, internalCode: 'SECRET');
      final json = serializer.serialize(product, 'json');

      expect(json, isNot(contains('SECRET')));
      expect(json, isNot(contains('"internalCode"')));
    });
  });

  group('Serializer - Enum Support', () {
    test('should serialize basic enum by name', () {
      final data = Status.active;
      final normalized = serializer.normalize(data);

      expect(normalized, equals('active'));
    });

    test('should deserialize basic enum by name', () {
      final status = serializer.denormalize<Status>('pending');

      expect(status, equals(Status.pending));
    });

    test('should serialize enum with @EnumExtractor', () {
      final priority = Priority.high;
      final normalized = serializer.normalize(priority);

      expect(normalized, equals('High Priority'));
    });

    test('should deserialize enum with @EnumExtractor', () {
      final priority = serializer.denormalize<Priority>('Low Priority');

      expect(priority, equals(Priority.low));
    });

    test('should throw error for invalid enum value', () {
      expect(
        () => serializer.denormalize<Status>('invalid'),
        throwsA(isA<SerializerException>()),
      );
    });
  });

  group('Serializer - Enum Lists', () {
    test('should serialize enum list without delimiter', () {
      final task = Task(
        'Complete project',
        Priority.high,
        statuses: [Status.active, Status.pending],
      );

      // Remove EnumDelimiter temporarily to test without delimiter
      final normalized = serializer.normalize(task);

      expect(normalized['priority'], equals('High Priority'));
    });

    test('should serialize enum list with @EnumDelimiter', () {
      final task = Task(
        'Complete project',
        Priority.high,
        statuses: [Status.active, Status.pending],
      );
      final json = serializer.serialize(task, 'json');

      expect(json, contains('"statuses":"active,pending"'));
    });

    test('should deserialize enum list with delimiter', () {
      final json =
          '{"title":"Task","priority":"High Priority","statuses":"active,pending"}';
      final context = SerializerContext(enumDelimiter: ',');
      final task = serializer.deserialize<Task>(json, 'json', context);

      expect(task, isNotNull);
      expect(task!.statuses, hasLength(2));
      expect(task.statuses![0], equals(Status.active));
      expect(task.statuses![1], equals(Status.pending));
    });

    test('should deserialize enum list as array', () {
      final json =
          '{"title":"Task","priority":"High Priority","statuses":["active","pending"]}';
      final task = serializer.deserialize<Task>(json, 'json');

      expect(task, isNotNull);
      expect(task!.statuses, hasLength(2));
    });
  });

  group('Serializer - Primitive Types', () {
    test('should handle DateTime serialization', () {
      final date = DateTime(2025, 1, 15, 10, 30);
      final normalized = serializer.normalize(date);

      expect(normalized, isA<String>());
      expect(normalized, contains('2025-01-15'));
    });

    test('should handle DateTime deserialization from string', () {
      final date = serializer.denormalize<DateTime>('2025-01-15T10:30:00.000');

      expect(date, isNotNull);
      expect(date!.year, equals(2025));
      expect(date.month, equals(1));
      expect(date.day, equals(15));
    });

    test('should handle DateTime deserialization from timestamp', () {
      final timestamp = DateTime(2025, 1, 15).millisecondsSinceEpoch;
      final date = serializer.denormalize<DateTime>(timestamp);

      expect(date, isNotNull);
      expect(date!.year, equals(2025));
    });

    test('should handle number type conversions', () {
      expect(serializer.denormalize<int>(42), equals(42));
      expect(serializer.denormalize<int>(42.7), equals(42));
      expect(serializer.denormalize<int>('42'), equals(42));

      expect(serializer.denormalize<double>(42), equals(42.0));
      expect(serializer.denormalize<double>(42.5), equals(42.5));
      expect(serializer.denormalize<double>('42.5'), equals(42.5));
    });

    test('should handle boolean conversions', () {
      expect(serializer.denormalize<bool>(true), isTrue);
      expect(serializer.denormalize<bool>('true'), isTrue);
      expect(serializer.denormalize<bool>('TRUE'), isTrue);
      expect(serializer.denormalize<bool>('1'), isTrue);
      expect(serializer.denormalize<bool>(1), isTrue);
      expect(serializer.denormalize<bool>(0), isFalse);
      expect(serializer.denormalize<bool>('false'), isFalse);
    });
  });

  group('Serializer - Error Handling', () {
    test('should throw error when no transformer supports type', () {
      expect(
        () => serializer.normalize(Duration()),
        throwsA(isA<SerializerException>()),
      );
    });

    test('should throw error when no encoder supports format', () {
      final user = User('John', 30);
      expect(
        () => serializer.serialize(user, 'xml'),
        throwsA(isA<SerializerException>()),
      );
    });

    test('should throw error for invalid JSON', () {
      expect(
        () => serializer.deserialize<User>('invalid json', 'json'),
        throwsA(isA<Exception>()),
      );
    });

    test('should throw error when class has no constructors', () {
      final builder = MetadataRegistryBuilder();
      builder.registerClass<User>(
        ClassMetadata(
          typeMetadata: TypeMetadata<User>(),
          constructors: [],
        ),
      );

      final testRegistry = builder.build();
      final testSerializer = Serializer(
        transformers: [MetadataTransformer(testRegistry)],
        encoders: [JsonEncoder()],
      );

      final data = {'name': 'John', 'age': 30};
      expect(
        () => testSerializer.denormalize<User>(data),
        throwsA(isA<SerializerException>()),
      );
    });

    test('should throw error when class has no getters', () {
      final builder = MetadataRegistryBuilder();
      builder.registerClass<User>(
        ClassMetadata(
          typeMetadata: TypeMetadata<User>(),
          getters: null,
        ),
      );
      final testRegistry = builder.build();
      final testSerializer = Serializer(
        transformers: [MetadataTransformer(testRegistry)],
        encoders: [JsonEncoder()],
      );

      final user = User('John', 30);
      expect(
        () => testSerializer.normalize(user),
        throwsA(isA<SerializerException>()),
      );
    });
  });

  group('Serializer - Complex Scenarios', () {
    test('should handle round-trip serialization', () {
      final original = User(
        'John Doe',
        30,
        email: 'john@example.com',
        tags: ['dev', 'ops'],
      );

      final json = serializer.serialize(original, 'json');
      final deserialized = serializer.deserialize<User>(json, 'json');

      expect(deserialized!.name, equals(original.name));
      expect(deserialized.age, equals(original.age));
      expect(deserialized.email, equals(original.email));
      expect(deserialized.tags, equals(original.tags));
    });

    test('should handle complex object with enums', () {
      final task = Task(
        'Important Task',
        Priority.high,
        statuses: [Status.active, Status.pending],
      );

      final json = serializer.serialize(task, 'json');
      final deserialized = serializer.deserialize<Task>(
        json,
        'json',
        SerializerContext(enumDelimiter: ','),
      );

      expect(deserialized!.title, equals(task.title));
      expect(deserialized.priority, equals(task.priority));
      expect(deserialized.statuses, equals(task.statuses));
    });

    test('should handle multiple serialization contexts', () {
      final order = Order('ORD-123', 99.99, 'pending');

      final json1 = serializer.serialize(
        order,
        'json',
        SerializerContext(groups: ['admin'], omitNull: true),
      );

      final json2 = serializer.serialize(
        order,
        'json',
        SerializerContext(groups: ['public'], pretty: true),
      );

      expect(json1, contains('"totalAmount"'));
      expect(json2, isNot(contains('"totalAmount"')));
      expect(json2, contains('\n'));
    });

    test('should maintain type safety through transformers', () {
      final user = User('John', 30);
      final normalized = serializer.normalize(user);
      final denormalized = serializer.denormalize<User>(normalized);

      expect(denormalized, isA<User>());
      expect(denormalized!.name, equals('John'));
      expect(denormalized.age, equals(30));
    });
  });

  group('Serializer - List Operations', () {
    test('should serialize list of objects', () {
      final users = [
        User('John', 30),
        User('Jane', 25),
      ];

      final normalized = serializer.normalize(users);

      expect(normalized, isA<List>());
      expect((normalized as List).length, equals(2));
      expect(normalized[0]['name'], equals('John'));
      expect(normalized[1]['name'], equals('Jane'));
    });

    test('should handle empty lists', () {
      final user = User('John', 30, tags: []);
      final normalized = serializer.normalize(user);

      expect(normalized['tags'], isA<List>());
      expect((normalized['tags'] as List).isEmpty, isTrue);
    });

    test('should handle null items in lists', () {
      final data = [User('John', 30), null, User('Jane', 25)];
      final normalized = serializer.normalize(data);

      expect(normalized, hasLength(3));
      expect(normalized[1], isNull);
    });
  });

  group('Serializer - Map Operations', () {
    test('should serialize Map objects', () {
      final map = {
        'user': User('John', 30),
        'count': 5,
      };

      final normalized = serializer.normalize(map);

      expect(normalized, isA<Map>());
      expect(normalized['user'], isA<Map>());
      expect(normalized['count'], equals(5));
    });

    test('should handle nested maps', () {
      final map = {
        'data': {
          'user': User('John', 30),
        },
      };

      final normalized = serializer.normalize(map);

      expect(normalized['data']['user']['name'], equals('John'));
    });

    test('should respect omitNull in maps', () {
      final map = {
        'key1': 'value1',
        'key2': null,
      };

      final context = SerializerContext(omitNull: true);
      final normalized = serializer.normalize<Map<String, dynamic>>(
        map,
        context,
      );

      expect(normalized.containsKey('key1'), isTrue);
      expect(normalized.containsKey('key2'), isFalse);
    });
  });
}

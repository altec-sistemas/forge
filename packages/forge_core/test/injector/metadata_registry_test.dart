import 'package:forge_core/forge_core.dart';
import 'package:test/test.dart';

import 'fixtures/metadata_fixtures.dart';

void main() {
  group('MetadataRegistry - Class Registration', () {
    test('should register and retrieve class metadata', () {
      final builder = MetadataRegistryBuilder();

      final metadata = ClassMetadata(
        typeMetadata: TypeMetadata<UserService>(),
        annotations: [TestAnnotation('user-service')],
      );

      builder.registerClass<UserService>(metadata);
      final registry = builder.build();

      expect(registry.hasClassMetadata<UserService>(), isTrue);
      final retrieved = registry.getClassMetadata<UserService>();
      expect(retrieved, same(metadata));
    });

    test('should throw when class metadata not registered', () {
      final builder = MetadataRegistryBuilder();
      final registry = builder.build();

      expect(
        () => registry.getClassMetadata<UserService>(),
        throwsA(
          predicate(
            (e) =>
                e is StateError &&
                e.message.contains('No metadata registered for type'),
          ),
        ),
      );
    });

    test('hasClassMetadata should return false for unregistered class', () {
      final builder = MetadataRegistryBuilder();
      final registry = builder.build();

      expect(registry.hasClassMetadata<UserService>(), isFalse);
    });

    test('should register multiple classes', () {
      final builder = MetadataRegistryBuilder();

      builder.registerClass<UserService>(
        ClassMetadata(typeMetadata: TypeMetadata<UserService>()),
      );
      builder.registerClass<ProductService>(
        ClassMetadata(typeMetadata: TypeMetadata<ProductService>()),
      );
      builder.registerClass<OrderService>(
        ClassMetadata(typeMetadata: TypeMetadata<OrderService>()),
      );

      final registry = builder.build();

      expect(registry.hasClassMetadata<UserService>(), isTrue);
      expect(registry.hasClassMetadata<ProductService>(), isTrue);
      expect(registry.hasClassMetadata<OrderService>(), isTrue);
    });

    test('allClasses should return all registered classes', () {
      final builder = MetadataRegistryBuilder();

      builder.registerClass<UserService>(
        ClassMetadata(typeMetadata: TypeMetadata<UserService>()),
      );
      builder.registerClass<ProductService>(
        ClassMetadata(typeMetadata: TypeMetadata<ProductService>()),
      );

      final registry = builder.build();
      final allClasses = registry.allClasses;

      expect(allClasses, hasLength(2));
    });

    test('should handle class with annotations', () {
      final builder = MetadataRegistryBuilder();

      final metadata = ClassMetadata(
        typeMetadata: TypeMetadata<UserService>(),
        annotations: [
          TestAnnotation('test'),
          RouteAnnotation('/users'),
        ],
      );

      builder.registerClass<UserService>(metadata);
      final registry = builder.build();

      final retrieved = registry.getClassMetadata<UserService>();
      expect(retrieved.annotations, hasLength(2));
      expect(retrieved.hasAnnotation<TestAnnotation>(), isTrue);
      expect(retrieved.hasAnnotation<RouteAnnotation>(), isTrue);
    });
  });

  group('MetadataRegistry - Method Registration', () {
    test('should register class with methods', () {
      final builder = MetadataRegistryBuilder();

      final metadata = ClassMetadata(
        typeMetadata: TypeMetadata<UserService>(),
        methods: [
          MethodMetadata(
            returnType: TypeMetadata<String>(),
            name: 'getUsername',
            method: (instance) => (instance as UserService).getUsername,
            annotations: [TestAnnotation('method')],
          ),
        ],
      );

      builder.registerClass<UserService>(metadata);
      final registry = builder.build();

      final retrieved = registry.getClassMetadata<UserService>();
      expect(retrieved.methods, hasLength(1));
      expect(retrieved.methods![0].name, equals('getUsername'));
    });

    test('methods should have back-reference to class', () {
      final builder = MetadataRegistryBuilder();

      final metadata = ClassMetadata(
        typeMetadata: TypeMetadata<UserService>(),
        methods: [
          MethodMetadata(
            returnType: TypeMetadata<String>(),
            name: 'getUsername',
            method: (instance) => (instance as UserService).getUsername,
          ),
        ],
      );

      builder.registerClass<UserService>(metadata);
      final registry = builder.build();

      final retrieved = registry.getClassMetadata<UserService>();
      final method = retrieved.methods![0];
      expect(method.classMetadata, same(retrieved));
    });

    test('should invoke method reference', () {
      final builder = MetadataRegistryBuilder();

      final metadata = ClassMetadata(
        typeMetadata: TypeMetadata<UserService>(),
        methods: [
          MethodMetadata(
            returnType: TypeMetadata<String>(),
            name: 'getUsername',
            method: (instance) => (instance as UserService).getUsername,
          ),
        ],
      );

      builder.registerClass<UserService>(metadata);
      final registry = builder.build();

      final retrieved = registry.getClassMetadata<UserService>();
      final method = retrieved.methods![0];

      final service = UserService('john_doe');
      final methodRef = method.getMethod(service) as String Function();
      expect(methodRef(), equals('john_doe'));
    });

    test('methodsAnnotatedWith should filter by annotation', () {
      final builder = MetadataRegistryBuilder();

      final metadata = ClassMetadata(
        typeMetadata: TypeMetadata<UserService>(),
        methods: [
          MethodMetadata(
            returnType: TypeMetadata<String>(),
            name: 'getUsername',
            method: (instance) => (instance as UserService).getUsername,
            annotations: [RouteAnnotation('/username')],
          ),
          MethodMetadata(
            returnType: TypeMetadata<void>(),
            name: 'setUsername',
            method: (instance) => (instance as UserService).setUsername,
            annotations: [TestAnnotation('setter')],
          ),
          MethodMetadata(
            returnType: TypeMetadata<String>(),
            name: 'getEmail',
            method: (instance) => (instance as UserService).getEmail,
            annotations: [RouteAnnotation('/email')],
          ),
        ],
      );

      builder.registerClass<UserService>(metadata);
      final registry = builder.build();

      final retrieved = registry.getClassMetadata<UserService>();
      final routeMethods = retrieved.methodsAnnotatedWith<RouteAnnotation>();

      expect(routeMethods, hasLength(2));
      expect(routeMethods[0].name, equals('getUsername'));
      expect(routeMethods[1].name, equals('getEmail'));
    });

    test('hasMappedMethods should indicate if methods were mapped', () {
      final builder = MetadataRegistryBuilder();

      final withMethods = ClassMetadata(
        typeMetadata: TypeMetadata<UserService>(),
        methods: [
          MethodMetadata(
            returnType: TypeMetadata<String>(),
            name: 'getUsername',
            method: (instance) => (instance as UserService).getUsername,
          ),
        ],
      );

      final withoutMethods = ClassMetadata(
        typeMetadata: TypeMetadata<ProductService>(),
        methods: null,
      );

      builder.registerClass<UserService>(withMethods);
      builder.registerClass<ProductService>(withoutMethods);
      final registry = builder.build();

      expect(
        registry.getClassMetadata<UserService>().hasMappedMethods,
        isTrue,
      );
      expect(
        registry.getClassMetadata<ProductService>().hasMappedMethods,
        isFalse,
      );
    });
  });

  group('MetadataRegistry - Method Parameters', () {
    test('should register method with parameters', () {
      final builder = MetadataRegistryBuilder();

      final metadata = ClassMetadata(
        typeMetadata: TypeMetadata<UserService>(),
        methods: [
          MethodMetadata(
            returnType: TypeMetadata<void>(),
            name: 'updateUser',
            method: (instance) => (instance as UserService).updateUser,
            parameters: [
              ParameterMetadata(
                typeMetadata: TypeMetadata<String>(),
                name: 'username',
                index: 0,
                isOptional: false,
                isNamed: false,
              ),
              ParameterMetadata(
                typeMetadata: TypeMetadata<int>(),
                name: 'age',
                index: 1,
                isOptional: true,
                isNamed: false,
                defaultValue: 0,
              ),
            ],
          ),
        ],
      );

      builder.registerClass<UserService>(metadata);
      final registry = builder.build();

      final retrieved = registry.getClassMetadata<UserService>();
      final method = retrieved.methods![0];

      expect(method.parameters, hasLength(2));
      expect(method.parameters![0].name, equals('username'));
      expect(method.parameters![0].isOptional, isFalse);
      expect(method.parameters![1].name, equals('age'));
      expect(method.parameters![1].isOptional, isTrue);
    });

    test('parameters should have back-reference to method', () {
      final builder = MetadataRegistryBuilder();

      final metadata = ClassMetadata(
        typeMetadata: TypeMetadata<UserService>(),
        methods: [
          MethodMetadata(
            returnType: TypeMetadata<void>(),
            name: 'updateUser',
            method: (instance) => (instance as UserService).updateUser,
            parameters: [
              ParameterMetadata(
                typeMetadata: TypeMetadata<String>(),
                name: 'username',
                index: 0,
                isOptional: false,
                isNamed: false,
              ),
            ],
          ),
        ],
      );

      builder.registerClass<UserService>(metadata);
      final registry = builder.build();

      final retrieved = registry.getClassMetadata<UserService>();
      final method = retrieved.methods![0];
      final param = method.parameters![0];

      expect(param.functionMetadata, same(method));
      expect(param.methodMetadata, same(method));
    });

    test('parametersAnnotatedWith should filter parameters', () {
      final builder = MetadataRegistryBuilder();

      final metadata = ClassMetadata(
        typeMetadata: TypeMetadata<UserService>(),
        methods: [
          MethodMetadata(
            returnType: TypeMetadata<void>(),
            name: 'updateUser',
            method: (instance) => (instance as UserService).updateUser,
            parameters: [
              ParameterMetadata(
                typeMetadata: TypeMetadata<String>(),
                name: 'username',
                index: 0,
                isOptional: false,
                isNamed: false,
                annotations: [InjectAnnotation()],
              ),
              ParameterMetadata(
                typeMetadata: TypeMetadata<int>(),
                name: 'age',
                index: 1,
                isOptional: true,
                isNamed: false,
              ),
            ],
          ),
        ],
      );

      builder.registerClass<UserService>(metadata);
      final registry = builder.build();

      final retrieved = registry.getClassMetadata<UserService>();
      final method = retrieved.methods![0];
      final injectedParams = method.parametersAnnotatedWith<InjectAnnotation>();

      expect(injectedParams, hasLength(1));
      expect(injectedParams[0].name, equals('username'));
    });

    test('hasMappedParameters should indicate if parameters were mapped', () {
      final builder = MetadataRegistryBuilder();

      final metadata = ClassMetadata(
        typeMetadata: TypeMetadata<UserService>(),
        methods: [
          MethodMetadata(
            returnType: TypeMetadata<void>(),
            name: 'withParams',
            method: (instance) => (instance as UserService).updateUser,
            parameters: [
              ParameterMetadata(
                typeMetadata: TypeMetadata<String>(),
                name: 'username',
                index: 0,
                isOptional: false,
                isNamed: false,
              ),
            ],
          ),
          MethodMetadata(
            returnType: TypeMetadata<String>(),
            name: 'noParams',
            method: (instance) => (instance as UserService).getUsername,
            parameters: null,
          ),
        ],
      );

      builder.registerClass<UserService>(metadata);
      final registry = builder.build();

      final retrieved = registry.getClassMetadata<UserService>();
      expect(retrieved.methods![0].hasMappedParameters, isTrue);
      expect(retrieved.methods![1].hasMappedParameters, isFalse);
    });
  });

  group('MetadataRegistry - Getters', () {
    test('should register class with getters', () {
      final builder = MetadataRegistryBuilder();

      final metadata = ClassMetadata(
        typeMetadata: TypeMetadata<UserService>(),
        getters: [
          GetterMetadata(
            returnType: TypeMetadata<String>(),
            name: 'username',
            getter: (instance) => (instance as UserService).getUsername(),
            annotations: [TestAnnotation('username-getter')],
          ),
        ],
      );

      builder.registerClass<UserService>(metadata);
      final registry = builder.build();

      final retrieved = registry.getClassMetadata<UserService>();
      expect(retrieved.getters, hasLength(1));
      expect(retrieved.getters![0].name, equals('username'));
    });

    test('getters should have back-reference to class', () {
      final builder = MetadataRegistryBuilder();

      final metadata = ClassMetadata(
        typeMetadata: TypeMetadata<UserService>(),
        getters: [
          GetterMetadata(
            returnType: TypeMetadata<String>(),
            name: 'username',
            getter: (instance) => (instance as UserService).getUsername(),
          ),
        ],
      );

      builder.registerClass<UserService>(metadata);
      final registry = builder.build();

      final retrieved = registry.getClassMetadata<UserService>();
      final getter = retrieved.getters![0];
      expect(getter.classMetadata, same(retrieved));
    });

    test('should invoke getter', () {
      final builder = MetadataRegistryBuilder();

      final metadata = ClassMetadata(
        typeMetadata: TypeMetadata<UserService>(),
        getters: [
          GetterMetadata(
            returnType: TypeMetadata<String>(),
            name: 'username',
            getter: (instance) => (instance as UserService).getUsername(),
          ),
        ],
      );

      builder.registerClass<UserService>(metadata);
      final registry = builder.build();

      final retrieved = registry.getClassMetadata<UserService>();
      final getter = retrieved.getters![0];

      final service = UserService('jane_doe');
      expect(getter.getValue(service), equals('jane_doe'));
    });

    test('gettersAnnotatedWith should filter by annotation', () {
      final builder = MetadataRegistryBuilder();

      final metadata = ClassMetadata(
        typeMetadata: TypeMetadata<UserService>(),
        getters: [
          GetterMetadata(
            returnType: TypeMetadata<String>(),
            name: 'username',
            getter: (instance) => (instance as UserService).getUsername(),
            annotations: [RouteAnnotation('/username')],
          ),
          GetterMetadata(
            returnType: TypeMetadata<String>(),
            name: 'email',
            getter: (instance) => (instance as UserService).getEmail(),
            annotations: [TestAnnotation('email')],
          ),
        ],
      );

      builder.registerClass<UserService>(metadata);
      final registry = builder.build();

      final retrieved = registry.getClassMetadata<UserService>();
      final routeGetters = retrieved.gettersAnnotatedWith<RouteAnnotation>();

      expect(routeGetters, hasLength(1));
      expect(routeGetters[0].name, equals('username'));
    });

    test('hasMappedGetters should indicate if getters were mapped', () {
      final builder = MetadataRegistryBuilder();

      final withGetters = ClassMetadata(
        typeMetadata: TypeMetadata<UserService>(),
        getters: [],
      );
      final withoutGetters = ClassMetadata(
        typeMetadata: TypeMetadata<ProductService>(),
        getters: null,
      );

      builder.registerClass<UserService>(withGetters);
      builder.registerClass<ProductService>(withoutGetters);
      final registry = builder.build();

      expect(
        registry.getClassMetadata<UserService>().hasMappedGetters,
        isTrue,
      );
      expect(
        registry.getClassMetadata<ProductService>().hasMappedGetters,
        isFalse,
      );
    });
  });

  group('MetadataRegistry - Setters', () {
    test('should register class with setters', () {
      final builder = MetadataRegistryBuilder();

      final metadata = ClassMetadata(
        typeMetadata: TypeMetadata<UserService>(),
        setters: [
          SetterMetadata(
            valueType: TypeMetadata<String>(),
            name: 'username',
            setter: (instance, value) =>
                (instance as UserService).setUsername(value as String),
            annotations: [TestAnnotation('username-setter')],
          ),
        ],
      );

      builder.registerClass<UserService>(metadata);
      final registry = builder.build();

      final retrieved = registry.getClassMetadata<UserService>();
      expect(retrieved.setters, hasLength(1));
      expect(retrieved.setters![0].name, equals('username'));
    });

    test('setters should have back-reference to class', () {
      final builder = MetadataRegistryBuilder();

      final metadata = ClassMetadata(
        typeMetadata: TypeMetadata<UserService>(),
        setters: [
          SetterMetadata(
            valueType: TypeMetadata<String>(),
            name: 'username',
            setter: (instance, value) =>
                (instance as UserService).setUsername(value as String),
          ),
        ],
      );

      builder.registerClass<UserService>(metadata);
      final registry = builder.build();

      final retrieved = registry.getClassMetadata<UserService>();
      final setter = retrieved.setters![0];
      expect(setter.classMetadata, same(retrieved));
    });

    test('should invoke setter', () {
      final builder = MetadataRegistryBuilder();

      final metadata = ClassMetadata(
        typeMetadata: TypeMetadata<UserService>(),
        setters: [
          SetterMetadata(
            valueType: TypeMetadata<String>(),
            name: 'username',
            setter: (instance, value) =>
                (instance as UserService).setUsername(value as String),
          ),
        ],
      );

      builder.registerClass<UserService>(metadata);
      final registry = builder.build();

      final retrieved = registry.getClassMetadata<UserService>();
      final setter = retrieved.setters![0];

      final service = UserService('old_name');
      setter.setValue(service, 'new_name');
      expect(service.getUsername(), equals('new_name'));
    });

    test('settersAnnotatedWith should filter by annotation', () {
      final builder = MetadataRegistryBuilder();

      final metadata = ClassMetadata(
        typeMetadata: TypeMetadata<UserService>(),
        setters: [
          SetterMetadata(
            valueType: TypeMetadata<String>(),
            name: 'username',
            setter: (instance, value) =>
                (instance as UserService).setUsername(value as String),
            annotations: [ValidateAnnotation()],
          ),
          SetterMetadata(
            valueType: TypeMetadata<String>(),
            name: 'email',
            setter: (instance, value) {},
            annotations: [TestAnnotation('email')],
          ),
        ],
      );

      builder.registerClass<UserService>(metadata);
      final registry = builder.build();

      final retrieved = registry.getClassMetadata<UserService>();
      final validateSetters = retrieved
          .settersAnnotatedWith<ValidateAnnotation>();

      expect(validateSetters, hasLength(1));
      expect(validateSetters[0].name, equals('username'));
    });

    test('hasMappedSetters should indicate if setters were mapped', () {
      final builder = MetadataRegistryBuilder();

      final withSetters = ClassMetadata(
        typeMetadata: TypeMetadata<UserService>(),
        setters: [],
      );
      final withoutSetters = ClassMetadata(
        typeMetadata: TypeMetadata<ProductService>(),
        setters: null,
      );

      builder.registerClass<UserService>(withSetters);
      builder.registerClass<ProductService>(withoutSetters);
      final registry = builder.build();

      expect(
        registry.getClassMetadata<UserService>().hasMappedSetters,
        isTrue,
      );
      expect(
        registry.getClassMetadata<ProductService>().hasMappedSetters,
        isFalse,
      );
    });
  });

  group('MetadataRegistry - Constructors', () {
    test('should register class with constructors', () {
      final builder = MetadataRegistryBuilder();

      final metadata = ClassMetadata(
        typeMetadata: TypeMetadata<UserService>(),
        constructors: [
          ConstructorMetadata(
            name: '',
            factory: () => UserService.new,
            annotations: [TestAnnotation('default-constructor')],
          ),
        ],
      );

      builder.registerClass<UserService>(metadata);
      final registry = builder.build();

      final retrieved = registry.getClassMetadata<UserService>();
      expect(retrieved.constructors, hasLength(1));
      expect(retrieved.constructors![0].name, equals(''));
    });

    test('constructors should have back-reference to class', () {
      final builder = MetadataRegistryBuilder();

      final metadata = ClassMetadata(
        typeMetadata: TypeMetadata<UserService>(),
        constructors: [
          ConstructorMetadata(
            name: '',
            factory: () => UserService.new,
          ),
        ],
      );

      builder.registerClass<UserService>(metadata);
      final registry = builder.build();

      final retrieved = registry.getClassMetadata<UserService>();
      final constructor = retrieved.constructors![0];
      expect(constructor.classMetadata, same(retrieved));
    });

    test('should create instance using constructor factory', () {
      final builder = MetadataRegistryBuilder();

      final metadata = ClassMetadata(
        typeMetadata: TypeMetadata<UserService>(),
        constructors: [
          ConstructorMetadata(
            name: '',
            factory: () => UserService.new,
          ),
        ],
      );

      builder.registerClass<UserService>(metadata);
      final registry = builder.build();

      final retrieved = registry.getClassMetadata<UserService>();
      final constructor = retrieved.constructors![0];

      final instance = constructor.createInstance(['test_user']) as UserService;
      expect(instance.getUsername(), equals('test_user'));
    });

    test('constructor should have parameters', () {
      final builder = MetadataRegistryBuilder();

      final metadata = ClassMetadata(
        typeMetadata: TypeMetadata<UserService>(),
        constructors: [
          ConstructorMetadata(
            name: '',
            factory: () => UserService.new,
            parameters: [
              ParameterMetadata(
                typeMetadata: TypeMetadata<String>(),
                name: 'username',
                index: 0,
                isOptional: false,
                isNamed: false,
              ),
            ],
          ),
        ],
      );

      builder.registerClass<UserService>(metadata);
      final registry = builder.build();

      final retrieved = registry.getClassMetadata<UserService>();
      final constructor = retrieved.constructors![0];

      expect(constructor.parameters, hasLength(1));
      expect(constructor.parameters![0].name, equals('username'));
    });

    test('constructor parameters should have back-reference', () {
      final builder = MetadataRegistryBuilder();

      final metadata = ClassMetadata(
        typeMetadata: TypeMetadata<UserService>(),
        constructors: [
          ConstructorMetadata(
            name: '',
            factory: () => UserService.new,
            parameters: [
              ParameterMetadata(
                typeMetadata: TypeMetadata<String>(),
                name: 'username',
                index: 0,
                isOptional: false,
                isNamed: false,
              ),
            ],
          ),
        ],
      );

      builder.registerClass<UserService>(metadata);
      final registry = builder.build();

      final retrieved = registry.getClassMetadata<UserService>();
      final constructor = retrieved.constructors![0];
      final param = constructor.parameters![0];

      expect(param.functionMetadata, same(constructor));
      expect(param.constructorMetadata, same(constructor));
    });

    test('constructorsAnnotatedWith should filter by annotation', () {
      final builder = MetadataRegistryBuilder();

      final metadata = ClassMetadata(
        typeMetadata: TypeMetadata<UserService>(),
        constructors: [
          ConstructorMetadata(
            name: '',
            factory: () => UserService.new,
            annotations: [InjectAnnotation()],
          ),
          ConstructorMetadata(
            name: 'fromJson',
            factory: () => UserService.new,
            annotations: [TestAnnotation('json')],
          ),
        ],
      );

      builder.registerClass<UserService>(metadata);
      final registry = builder.build();

      final retrieved = registry.getClassMetadata<UserService>();
      final injectConstructors = retrieved
          .constructorsAnnotatedWith<InjectAnnotation>();

      expect(injectConstructors, hasLength(1));
      expect(injectConstructors[0].name, equals(''));
    });

    test(
      'hasMappedConstructors should indicate if constructors were mapped',
      () {
        final builder = MetadataRegistryBuilder();

        final withConstructors = ClassMetadata(
          typeMetadata: TypeMetadata<UserService>(),
          constructors: [],
        );
        final withoutConstructors = ClassMetadata(
          typeMetadata: TypeMetadata<ProductService>(),
          constructors: null,
        );

        builder.registerClass<UserService>(withConstructors);
        builder.registerClass<ProductService>(withoutConstructors);
        final registry = builder.build();

        expect(
          registry.getClassMetadata<UserService>().hasMappedConstructors,
          isTrue,
        );
        expect(
          registry.getClassMetadata<ProductService>().hasMappedConstructors,
          isFalse,
        );
      },
    );
  });

  group('MetadataRegistry - Global Queries', () {
    test('classesAnnotatedWith should find all annotated classes', () {
      final builder = MetadataRegistryBuilder();

      builder.registerClass<UserService>(
        ClassMetadata(
          typeMetadata: TypeMetadata<UserService>(),
          annotations: [RouteAnnotation('/users')],
        ),
      );
      builder.registerClass<ProductService>(
        ClassMetadata(
          typeMetadata: TypeMetadata<ProductService>(),
          annotations: [RouteAnnotation('/products')],
        ),
      );
      builder.registerClass<OrderService>(
        ClassMetadata(
          typeMetadata: TypeMetadata<OrderService>(),
          annotations: [TestAnnotation('order')],
        ),
      );

      final registry = builder.build();
      final routeClasses = registry.classesAnnotatedWith<RouteAnnotation>();

      expect(routeClasses, hasLength(2));
    });

    test('methodsAnnotatedWith should find methods across all classes', () {
      final builder = MetadataRegistryBuilder();

      builder.registerClass<UserService>(
        ClassMetadata(
          typeMetadata: TypeMetadata<UserService>(),
          methods: [
            MethodMetadata(
              returnType: TypeMetadata<String>(),
              name: 'getUsername',
              method: (instance) => (instance as UserService).getUsername,
              annotations: [RouteAnnotation('/username')],
            ),
          ],
        ),
      );
      builder.registerClass<ProductService>(
        ClassMetadata(
          typeMetadata: TypeMetadata<ProductService>(),
          methods: [
            MethodMetadata(
              returnType: TypeMetadata<String>(),
              name: 'getName',
              method: (instance) => (instance as ProductService).getName,
              annotations: [RouteAnnotation('/product-name')],
            ),
          ],
        ),
      );

      final registry = builder.build();
      final routeMethods = registry.methodsAnnotatedWith<RouteAnnotation>();

      expect(routeMethods, hasLength(2));
    });

    test(
      'parametersAnnotatedWith should find parameters across all classes',
      () {
        final builder = MetadataRegistryBuilder();

        builder.registerClass<UserService>(
          ClassMetadata(
            typeMetadata: TypeMetadata<UserService>(),
            methods: [
              MethodMetadata(
                returnType: TypeMetadata<void>(),
                name: 'updateUser',
                method: (instance) => (instance as UserService).updateUser,
                parameters: [
                  ParameterMetadata(
                    typeMetadata: TypeMetadata<String>(),
                    name: 'username',
                    index: 0,
                    isOptional: false,
                    isNamed: false,
                    annotations: [InjectAnnotation()],
                  ),
                ],
              ),
            ],
          ),
        );
        builder.registerClass<ProductService>(
          ClassMetadata(
            typeMetadata: TypeMetadata<ProductService>(),
            methods: [
              MethodMetadata(
                returnType: TypeMetadata<void>(),
                name: 'updateProduct',
                method: (instance) =>
                    (instance as ProductService).updateProduct,
                parameters: [
                  ParameterMetadata(
                    typeMetadata: TypeMetadata<String>(),
                    name: 'name',
                    index: 0,
                    isOptional: false,
                    isNamed: false,
                    annotations: [InjectAnnotation()],
                  ),
                ],
              ),
            ],
          ),
        );

        final registry = builder.build();
        final injectParams = registry
            .parametersAnnotatedWith<InjectAnnotation>();

        expect(injectParams, hasLength(2));
      },
    );

    test('gettersAnnotatedWith should find getters across all classes', () {
      final builder = MetadataRegistryBuilder();

      builder.registerClass<UserService>(
        ClassMetadata(
          typeMetadata: TypeMetadata<UserService>(),
          getters: [
            GetterMetadata(
              returnType: TypeMetadata<String>(),
              name: 'username',
              getter: (instance) => (instance as UserService).getUsername(),
              annotations: [RouteAnnotation('/username')],
            ),
          ],
        ),
      );
      builder.registerClass<ProductService>(
        ClassMetadata(
          typeMetadata: TypeMetadata<ProductService>(),
          getters: [
            GetterMetadata(
              returnType: TypeMetadata<String>(),
              name: 'name',
              getter: (instance) => (instance as ProductService).getName(),
              annotations: [RouteAnnotation('/product-name')],
            ),
          ],
        ),
      );

      final registry = builder.build();
      final routeGetters = registry.gettersAnnotatedWith<RouteAnnotation>();

      expect(routeGetters, hasLength(2));
    });

    test('settersAnnotatedWith should find setters across all classes', () {
      final builder = MetadataRegistryBuilder();

      builder.registerClass<UserService>(
        ClassMetadata(
          typeMetadata: TypeMetadata<UserService>(),
          setters: [
            SetterMetadata(
              valueType: TypeMetadata<String>(),
              name: 'username',
              setter: (instance, value) =>
                  (instance as UserService).setUsername(value as String),
              annotations: [ValidateAnnotation()],
            ),
          ],
        ),
      );
      builder.registerClass<ProductService>(
        ClassMetadata(
          typeMetadata: TypeMetadata<ProductService>(),
          setters: [
            SetterMetadata(
              valueType: TypeMetadata<String>(),
              name: 'name',
              setter: (instance, value) =>
                  (instance as ProductService).setName(value as String),
              annotations: [ValidateAnnotation()],
            ),
          ],
        ),
      );

      final registry = builder.build();
      final validateSetters = registry
          .settersAnnotatedWith<ValidateAnnotation>();

      expect(validateSetters, hasLength(2));
    });

    test(
      'constructorsAnnotatedWith should find constructors across all classes',
      () {
        final builder = MetadataRegistryBuilder();

        builder.registerClass<UserService>(
          ClassMetadata(
            typeMetadata: TypeMetadata<UserService>(),
            constructors: [
              ConstructorMetadata(
                name: '',
                factory: () => UserService.new,
                annotations: [InjectAnnotation()],
              ),
            ],
          ),
        );
        builder.registerClass<ProductService>(
          ClassMetadata(
            typeMetadata: TypeMetadata<ProductService>(),
            constructors: [
              ConstructorMetadata(
                name: '',
                factory: () => ProductService.new,
                annotations: [InjectAnnotation()],
              ),
            ],
          ),
        );

        final registry = builder.build();
        final injectConstructors = registry
            .constructorsAnnotatedWith<InjectAnnotation>();

        expect(injectConstructors, hasLength(2));
      },
    );
  });

  group('MetadataRegistry - Annotation Utilities', () {
    test('ElementMetadata should find first annotation of type', () {
      final metadata = ClassMetadata(
        typeMetadata: TypeMetadata<UserService>(),
        annotations: [
          TestAnnotation('first'),
          RouteAnnotation('/users'),
          TestAnnotation('second'),
        ],
      );

      final testAnnotation = metadata.firstAnnotationOf<TestAnnotation>();
      expect(testAnnotation, isNotNull);
      expect(testAnnotation!.value, equals('first'));
    });

    test('ElementMetadata should return null if annotation not found', () {
      final metadata = ClassMetadata(
        typeMetadata: TypeMetadata<UserService>(),
        annotations: [TestAnnotation('test')],
      );

      final routeAnnotation = metadata.firstAnnotationOf<RouteAnnotation>();
      expect(routeAnnotation, isNull);
    });

    test('ElementMetadata should find all annotations of type', () {
      final metadata = ClassMetadata(
        typeMetadata: TypeMetadata<UserService>(),
        annotations: [
          TestAnnotation('first'),
          RouteAnnotation('/users'),
          TestAnnotation('second'),
        ],
      );

      final testAnnotations = metadata.allAnnotationsOf<TestAnnotation>();
      expect(testAnnotations, hasLength(2));
      expect(testAnnotations[0].value, equals('first'));
      expect(testAnnotations[1].value, equals('second'));
    });

    test('ElementMetadata should check if has annotation', () {
      final metadata = ClassMetadata(
        typeMetadata: TypeMetadata<UserService>(),
        annotations: [TestAnnotation('test')],
      );

      expect(metadata.hasAnnotation<TestAnnotation>(), isTrue);
      expect(metadata.hasAnnotation<RouteAnnotation>(), isFalse);
    });
  });

  group('MetadataRegistry - Complex Scenarios', () {
    test('should handle class with all member types', () {
      final builder = MetadataRegistryBuilder();

      final metadata = ClassMetadata(
        typeMetadata: TypeMetadata<UserService>(),
        methods: [
          MethodMetadata(
            returnType: TypeMetadata<String>(),
            name: 'getUsername',
            method: (instance) => (instance as UserService).getUsername,
          ),
        ],
        getters: [
          GetterMetadata(
            returnType: TypeMetadata<String>(),
            name: 'username',
            getter: (instance) => (instance as UserService).getUsername(),
          ),
        ],
        setters: [
          SetterMetadata(
            valueType: TypeMetadata<String>(),
            name: 'username',
            setter: (instance, value) =>
                (instance as UserService).setUsername(value as String),
          ),
        ],
        constructors: [
          ConstructorMetadata(
            name: '',
            factory: () => UserService.new,
          ),
        ],
        annotations: [TestAnnotation('complete')],
      );

      builder.registerClass<UserService>(metadata);
      final registry = builder.build();

      final retrieved = registry.getClassMetadata<UserService>();
      expect(retrieved.hasMappedMethods, isTrue);
      expect(retrieved.hasMappedGetters, isTrue);
      expect(retrieved.hasMappedSetters, isTrue);
      expect(retrieved.hasMappedConstructors, isTrue);
      expect(retrieved.methods, hasLength(1));
      expect(retrieved.getters, hasLength(1));
      expect(retrieved.setters, hasLength(1));
      expect(retrieved.constructors, hasLength(1));
    });

    test('should handle multiple classes with cross-references', () {
      final builder = MetadataRegistryBuilder();

      builder.registerClass<UserService>(
        ClassMetadata(
          typeMetadata: TypeMetadata<UserService>(),
          methods: [
            MethodMetadata(
              returnType: TypeMetadata<String>(),
              name: 'getUsername',
              method: (instance) => (instance as UserService).getUsername,
              annotations: [RouteAnnotation('/users/username')],
            ),
          ],
        ),
      );

      builder.registerClass<ProductService>(
        ClassMetadata(
          typeMetadata: TypeMetadata<ProductService>(),
          methods: [
            MethodMetadata(
              returnType: TypeMetadata<String>(),
              name: 'getName',
              method: (instance) => (instance as ProductService).getName,
              annotations: [RouteAnnotation('/products/name')],
            ),
          ],
        ),
      );

      final registry = builder.build();

      expect(registry.allClasses, hasLength(2));
      expect(
        registry.methodsAnnotatedWith<RouteAnnotation>(),
        hasLength(2),
      );
    });

    test('should maintain immutability after build', () {
      final builder = MetadataRegistryBuilder();

      builder.registerClass<UserService>(
        ClassMetadata(typeMetadata: TypeMetadata<UserService>()),
      );
      final registry = builder.build();

      // Registering more after build shouldn't affect the built registry
      builder.registerClass<ProductService>(
        ClassMetadata(typeMetadata: TypeMetadata<ProductService>()),
      );

      expect(registry.allClasses, hasLength(1));
    });

    test('registry should handle empty registration', () {
      final builder = MetadataRegistryBuilder();
      final registry = builder.build();

      expect(registry.allClasses, isEmpty);
      expect(registry.classesAnnotatedWith<TestAnnotation>(), isEmpty);
      expect(registry.methodsAnnotatedWith<RouteAnnotation>(), isEmpty);
    });
  });
}

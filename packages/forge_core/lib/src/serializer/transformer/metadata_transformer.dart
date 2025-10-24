import '../../../forge_core.dart';

class _PropertyCache {
  final Map<String, GetterMetadata> gettersByName = {};
  final Map<String, SetterMetadata> settersByName = {};
  final List<GetterMetadata> activeGetters = [];
  final List<SetterMetadata> activeSetters = [];
}

class _MetadataCache {
  final Map<Type, _PropertyCache> _classCache = {};
  final Map<Type, ClassMetadata> _classMetadata = {};
  final Map<Type, EnumMetadata> _enumMetadata = {};
  final Map<Type, bool> _typeChecks = {};

  _PropertyCache getPropertyCache(
    ClassMetadata metadata,
    SerializerContext context,
  ) {
    final key = metadata.typeMetadata.type;

    var cache = _classCache[key];
    if (cache != null) return cache;

    cache = _PropertyCache();

    if (metadata.hasMappedGetters) {
      for (final getter in metadata.getters!) {
        cache.gettersByName[getter.name] = getter;

        if (getter.hasAnnotation<Ignore>() && !context.showIgnored) {
          continue;
        }

        final propertyAnnotation = getter.firstAnnotationOf<Property>();
        if (context.groups.isNotEmpty && propertyAnnotation?.groups != null) {
          final hasMatchingGroup = propertyAnnotation!.groups!.any(
            (group) => context.groups.contains(group),
          );
          if (!hasMatchingGroup) continue;
        }

        cache.activeGetters.add(getter);
      }
    }

    if (metadata.hasMappedSetters) {
      for (final setter in metadata.setters!) {
        cache.settersByName[setter.name] = setter;

        if (setter.hasAnnotation<Ignore>() && !context.showIgnored) {
          continue;
        }

        final propertyAnnotation = setter.firstAnnotationOf<Property>();
        if (context.groups.isNotEmpty && propertyAnnotation?.groups != null) {
          final hasMatchingGroup = propertyAnnotation!.groups!.any(
            (group) => context.groups.contains(group),
          );
          if (!hasMatchingGroup) continue;
        }

        cache.activeSetters.add(setter);
      }
    }

    _classCache[key] = cache;
    return cache;
  }

  void clear() {
    _classCache.clear();
    _classMetadata.clear();
    _enumMetadata.clear();
    _typeChecks.clear();
  }
}

class MetadataTransformer implements Transformer, SerializerAware {
  final MetadataRegistry _metadataRegistry;
  final _MetadataCache _cache = _MetadataCache();
  late Serializer _serializer;

  static final _primitiveTypes = {int, double, num, String, bool, DateTime};

  MetadataTransformer(this._metadataRegistry);

  @override
  void setSerializer(Serializer serializer) {
    _serializer = serializer;
  }

  @override
  bool supportsNormalization<T>(T object, SerializerContext context) {
    if (object == null) return false;

    if (_metadataRegistry.hasClassMetadata<T>(object.runtimeType)) {
      return true;
    }

    if (_metadataRegistry.hasEnumMetadata<T>(object.runtimeType)) {
      return true;
    }

    if (<T>[] is List<List> && object is List) {
      return _getClassMetadataForList<T>() != null ||
          _getEnumMetadataForList<T>() != null;
    }

    return false;
  }

  @override
  bool supportsDenormalization<T>(dynamic data, SerializerContext context) {
    if (_metadataRegistry.hasClassMetadata<T>()) {
      return true;
    }

    if (_metadataRegistry.hasEnumMetadata<T>()) {
      return true;
    }

    if (<T>[] is List<List>) {
      return _getClassMetadataForList<T>() != null ||
          _getEnumMetadataForList<T>() != null;
    }

    return false;
  }

  @override
  dynamic normalize<T>(T object, SerializerContext context) {
    if (object == null) return null;

    if (_metadataRegistry.hasEnumMetadata<T>(object.runtimeType)) {
      final metadata = _metadataRegistry.getEnumMetadata<T>(object.runtimeType);
      return _normalizeEnum(object, metadata, context);
    }

    if (<T>[] is List<List> && object is List) {
      final classMeta = _getClassMetadataForList<T>();
      if (classMeta != null) {
        return _normalizeList(
          object,
          TypeMetadata<List>([classMeta.typeMetadata]),
          context,
        );
      }

      final enumMeta = _getEnumMetadataForList<T>();
      if (enumMeta != null) {
        return _normalizeEnumList(object, enumMeta, context);
      }
    }

    final metadata = _metadataRegistry.getClassMetadata<T>(object.runtimeType);
    return _normalizeObject(object, metadata, context);
  }

  dynamic _normalizeObject<T>(
    T object,
    ClassMetadata metadata,
    SerializerContext context,
  ) {
    if (!metadata.hasMappedGetters) {
      throw SerializerException('Class $T has no mapped getters');
    }

    final cache = _cache.getPropertyCache(metadata, context);
    final result = <String, dynamic>{};

    for (final getterMeta in cache.activeGetters) {
      var effectiveContext = context;

      if (getterMeta.hasAnnotation<EnumDelimiter>()) {
        effectiveContext = context.copyWith(
          enumDelimiter: getterMeta
              .firstAnnotationOf<EnumDelimiter>()!
              .delimiter,
        );
      }

      final propertyAnnotation = getterMeta.firstAnnotationOf<Property>();
      final value = getterMeta.getValue(object);

      if (value == null && context.omitNull) {
        continue;
      }

      final propertyName = propertyAnnotation?.name ?? getterMeta.name;

      if (value != null) {
        final normalizedValue = getterMeta.typeMetadata.captureGeneric(
          <S>() => _normalizeValue<S>(
            value as S?,
            getterMeta.typeMetadata,
            effectiveContext,
          ),
        );
        result[propertyName] = normalizedValue;
      } else {
        result[propertyName] = null;
      }
    }

    return result;
  }

  dynamic _normalizeEnum(
    dynamic enumValue,
    EnumMetadata metadata,
    SerializerContext context,
  ) {
    if (!metadata.hasMappedValues) {
      throw SerializerException(
        'Enum ${metadata.typeMetadata.type} has no mapped values',
      );
    }

    final enumValueMeta = metadata.values!.firstWhere(
      (v) => v.value == enumValue,
      orElse: () =>
          throw SerializerException('Enum value not found: $enumValue'),
    );

    final extractorAnnotation = metadata.firstAnnotationOf<EnumExtractor>();
    if (extractorAnnotation != null) {
      return _extractEnumValue(enumValue, metadata, extractorAnnotation);
    }

    return enumValueMeta.name;
  }

  dynamic _normalizeEnumList(
    List list,
    EnumMetadata enumMeta,
    SerializerContext context,
  ) {
    final delimiter = context.enumDelimiter;

    if (delimiter != null) {
      final normalizedList = List<String>.filled(
        list.length,
        '',
        growable: false,
      );
      for (var i = 0; i < list.length; i++) {
        final normalized = _normalizeEnum(list[i], enumMeta, context);
        normalizedList[i] = normalized.toString();
      }
      return normalizedList.join(delimiter);
    }

    return list
        .map((item) => _normalizeEnum(item, enumMeta, context).toString())
        .toList();
  }

  dynamic _normalizeValue<T>(
    T? value,
    TypeMetadata type,
    SerializerContext context,
  ) {
    if (value == null) return null;

    if (_primitiveTypes.contains(type.type)) {
      return value;
    }

    if (type.type == List && type.typeArguments.isNotEmpty) {
      return _normalizeList(value, type, context);
    }

    return _serializer.normalize<T>(value, context);
  }

  dynamic _normalizeList<T>(
    T value,
    TypeMetadata type,
    SerializerContext context,
  ) {
    if (value is! List) {
      throw SerializerException(
        'Expected List for normalization of type ${type.type}, got ${value.runtimeType}',
      );
    }

    final itemType = type.typeArguments.first;

    final normalized = itemType.captureGeneric(
      <S>() => value.map((item) {
        return _normalizeValue<S>(
          item as S?,
          itemType as TypeMetadata<S>,
          context,
        );
      }).toList(),
    );

    if (itemType.captureGeneric(<S>() => <S>[] is List<Enum>) &&
        context.enumDelimiter != null) {
      return normalized.join(context.enumDelimiter!);
    }

    return normalized;
  }

  @override
  T denormalize<T>(dynamic data, SerializerContext context) {
    if (data == null) return null as T;

    if (_metadataRegistry.hasEnumMetadata<T>()) {
      final metadata = _metadataRegistry.getEnumMetadata<T>();
      return _denormalizeEnum(data, metadata, context);
    }

    if (<T>[] is List<List>) {
      final enumMeta = _getEnumMetadataForList<T>();
      if (enumMeta != null) {
        return _denormalizeEnumList(data, enumMeta, context);
      }

      final classMeta = _getClassMetadataForList<T>();
      if (classMeta != null) {
        return _denormalizeList(
          data,
          TypeMetadata<List>([classMeta.typeMetadata]),
          context,
        );
      }
    }

    final metadata = _metadataRegistry.getClassMetadata<T>();
    return _denormalizeObject<T>(data, metadata, context);
  }

  T _denormalizeObject<T>(
    dynamic data,
    ClassMetadata metadata,
    SerializerContext context,
  ) {
    if (!metadata.hasMappedConstructors || metadata.constructors!.isEmpty) {
      throw SerializerException('Class $T has no mapped constructors');
    }

    final constructor = metadata.constructors!.first;
    final positionalArgs = <dynamic>[];
    final namedArgs = <Symbol, dynamic>{};

    if (constructor.hasMappedParameters) {
      for (final param in constructor.parameters!) {
        final value = _extractParameterValue(param, data, metadata, context);

        if (param.isNamed) {
          namedArgs[Symbol(param.name)] = value;
        } else {
          while (positionalArgs.length < param.index) {
            positionalArgs.add(null);
          }
          if (positionalArgs.length == param.index) {
            positionalArgs.add(value);
          } else {
            positionalArgs[param.index] = value;
          }
        }
      }
    }

    final instance = constructor.createInstance(positionalArgs, namedArgs);

    if (metadata.hasMappedSetters) {
      _processSetters(instance, data, metadata, context);
    }

    return instance;
  }

  dynamic _denormalizeEnum(
    dynamic data,
    EnumMetadata metadata,
    SerializerContext context,
  ) {
    if (!metadata.hasMappedValues) {
      throw SerializerException(
        'Enum ${metadata.typeMetadata.type} has no mapped values',
      );
    }

    final extractorAnnotation = metadata.firstAnnotationOf<EnumExtractor>();
    if (extractorAnnotation != null) {
      return _findEnumByExtractedValue(data, metadata, extractorAnnotation);
    }

    if (data is! String) {
      throw SerializerException(
        'Expected String for enum denormalization, got ${data.runtimeType}',
      );
    }

    final enumValueMeta = metadata.getValueByName(data);
    if (enumValueMeta == null) {
      throw SerializerException(
        'Enum value "$data" not found in ${metadata.typeMetadata.type}',
      );
    }

    return enumValueMeta.value;
  }

  T _denormalizeEnumList<T>(
    dynamic data,
    EnumMetadata enumMeta,
    SerializerContext context,
  ) {
    final List<dynamic> items;
    final delimiter = context.enumDelimiter;

    if (data is String && delimiter != null) {
      items = data.split(delimiter);
    } else if (data is List) {
      items = data;
    } else {
      throw SerializerException(
        'Expected String or List for enum list denormalization, got ${data.runtimeType}',
      );
    }

    final result = items
        .map((item) => _denormalizeEnum(item, enumMeta, context))
        .toList();

    return enumMeta.typeMetadata.captureGeneric(<S>() => result.cast<S>()) as T;
  }

  dynamic _denormalizeValue<T>(
    dynamic value,
    TypeMetadata<T> targetType,
    SerializerContext context,
  ) {
    if (value == null) return null;

    if (_primitiveTypes.contains(targetType.type)) {
      return value;
    }

    if (targetType.type == List && targetType.typeArguments.isNotEmpty) {
      return _denormalizeList(value, targetType, context);
    }

    return targetType.captureGeneric(
      <S>() => _serializer.denormalize<S>(value, context),
    );
  }

  dynamic _denormalizeList<T>(
    dynamic value,
    TypeMetadata<T> targetType,
    SerializerContext context,
  ) {
    final itemType = targetType.typeArguments.first;
    final isEnumList = _metadataRegistry.hasEnumMetadata(itemType.type);
    final delimiter = context.enumDelimiter;

    if (isEnumList && (value is String || delimiter != null)) {
      return itemType.captureGeneric(
        <S>() => _serializer.denormalize<List<S>>(value, context),
      );
    }

    if (value is! List) {
      throw SerializerException(
        'Expected List for denormalization to ${targetType.type}, got ${value.runtimeType}',
      );
    }

    final denormalizedList = itemType.captureGeneric(
      <S>() => value.map((item) {
        return _denormalizeValue<S>(item, itemType as TypeMetadata<S>, context);
      }).toList(),
    );

    return itemType.captureGeneric(<S>() => denormalizedList.cast<S>().toList())
        as T;
  }

  dynamic _extractEnumValue(
    dynamic enumValue,
    EnumMetadata metadata,
    EnumExtractor extractorAnnotation,
  ) {
    final getter = metadata.getters?.firstWhere(
      (g) => g.name == extractorAnnotation.fieldName,
      orElse: () => throw SerializerException(
        'Getter ${extractorAnnotation.fieldName} not found in enum ${metadata.typeMetadata.type}',
      ),
    );

    if (getter == null) {
      throw SerializerException(
        'No getters mapped for enum ${metadata.typeMetadata.type}',
      );
    }

    return getter.getValue(enumValue);
  }

  dynamic _findEnumByExtractedValue(
    dynamic data,
    EnumMetadata metadata,
    EnumExtractor extractorAnnotation,
  ) {
    final getter = metadata.getters?.firstWhere(
      (g) => g.name == extractorAnnotation.fieldName,
      orElse: () => throw SerializerException(
        'Getter ${extractorAnnotation.fieldName} not found in enum ${metadata.typeMetadata.type}',
      ),
    );

    if (getter == null) {
      throw SerializerException(
        'No getters mapped for enum ${metadata.typeMetadata.type}',
      );
    }

    for (final enumValueMeta in metadata.values!) {
      final extractedValue = getter.getValue(enumValueMeta.value);
      if (extractedValue == data) {
        return enumValueMeta.value;
      }
    }

    throw SerializerException(
      'No enum value found with ${extractorAnnotation.fieldName} = $data',
    );
  }

  dynamic _extractParameterValue(
    ParameterMetadata param,
    dynamic data,
    ClassMetadata metadata,
    SerializerContext context,
  ) {
    String propertyName = param.name;
    var effectiveContext = context;

    final matchingGetter = metadata.getters?.firstWhere(
      (g) => g.name == param.name,
      orElse: () => throw SerializerException(
        'No getter found for parameter ${param.name} in class ${metadata.typeMetadata.type}',
      ),
    );

    if (matchingGetter != null) {
      final propertyAnnotation = matchingGetter.firstAnnotationOf<Property>();
      propertyName = propertyAnnotation?.name ?? param.name;

      if (matchingGetter.hasAnnotation<EnumDelimiter>()) {
        effectiveContext = effectiveContext.copyWith(
          enumDelimiter: matchingGetter
              .firstAnnotationOf<EnumDelimiter>()!
              .delimiter,
        );
      }
    }

    dynamic value = data[propertyName];

    if (value != null) {
      value = param.typeMetadata.captureGeneric(
        <S>() => _denormalizeValue<S>(
          value,
          param.typeMetadata as TypeMetadata<S>,
          effectiveContext,
        ),
      );
    } else {
      value = param.defaultValue;
    }

    return value;
  }

  void _processSetters(
    dynamic instance,
    dynamic data,
    ClassMetadata metadata,
    SerializerContext context,
  ) {
    final cache = _cache.getPropertyCache(metadata, context);

    for (final setterMeta in cache.activeSetters) {
      final propertyAnnotation = setterMeta.firstAnnotationOf<Property>();
      final propertyName = propertyAnnotation?.name ?? setterMeta.name;
      dynamic value = data[propertyName];

      if (value != null) {
        var effectiveContext = context;

        if (setterMeta.hasAnnotation<EnumDelimiter>()) {
          effectiveContext = effectiveContext.copyWith(
            enumDelimiter: setterMeta
                .firstAnnotationOf<EnumDelimiter>()!
                .delimiter,
          );
        }

        value = setterMeta.typeMetadata.captureGeneric(
          <S>() => _denormalizeValue<S>(
            value,
            setterMeta.typeMetadata as TypeMetadata<S>,
            effectiveContext,
          ),
        );
      }

      setterMeta.setValue(instance, value);
    }
  }

  ClassMetadata? _getClassMetadataForList<T>() {
    final allClasses = _metadataRegistry.allClasses;

    for (final clazz in allClasses) {
      final typeMeta = clazz.typeMetadata;
      if (typeMeta.captureGeneric(<S>() => <S>[]) is T) {
        return clazz;
      }
    }

    return null;
  }

  EnumMetadata? _getEnumMetadataForList<T>() {
    final allEnums = _metadataRegistry.allEnums;

    for (final enumMeta in allEnums) {
      final typeMeta = enumMeta.typeMetadata;
      if (typeMeta.captureGeneric(<S>() => <S>[]) is T) {
        return enumMeta;
      }
    }

    return null;
  }
}

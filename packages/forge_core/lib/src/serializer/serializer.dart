import 'dart:collection';
import 'dart:convert' as c;

import '../../forge_core.dart';

export 'transformer/metadata_transformer.dart';

abstract class Serializer {
  factory Serializer({
    required List<Transformer> transformers,
    required List<Encoder> encoders,
  }) => _SerializerImpl(transformers, encoders);

  String serialize<T>(T object, String format, [SerializerContext? context]);
  T? deserialize<T>(String data, String format, [SerializerContext? context]);
  dynamic normalize<T>(T object, [SerializerContext? context]);
  T? denormalize<T>(dynamic data, [SerializerContext? context]);
  String encode(dynamic data, String format, [SerializerContext? context]);
  dynamic decode(String data, String format, [SerializerContext? context]);
}

class SerializerContext {
  final List<String> groups;
  final bool omitNull;
  final bool pretty;
  final bool showIgnored;
  final bool denormalizeValidate;
  final String? enumDelimiter;
  final Map<String, dynamic> extra;

  SerializerContext({
    List<String> groups = const [],
    this.omitNull = false,
    this.pretty = false,
    this.showIgnored = false,
    this.denormalizeValidate = true,
    this.enumDelimiter,
    Map<String, dynamic> extra = const {},
  }) : groups = UnmodifiableListView(groups),
       extra = UnmodifiableMapView(extra);

  SerializerContext copyWith({
    List<String>? groups,
    bool? omitNull,
    bool? pretty,
    bool? showIgnored,
    bool? denormalizeValidate,
    String? enumDelimiter,
    Map<String, dynamic>? extra,
  }) {
    return SerializerContext(
      groups: groups ?? this.groups,
      omitNull: omitNull ?? this.omitNull,
      pretty: pretty ?? this.pretty,
      showIgnored: showIgnored ?? this.showIgnored,
      denormalizeValidate: denormalizeValidate ?? this.denormalizeValidate,
      enumDelimiter: enumDelimiter ?? this.enumDelimiter,
      extra: extra ?? this.extra,
    );
  }
}

abstract class Transformer {
  dynamic normalize<T>(T object, SerializerContext context);
  bool supportsNormalization<T>(T object, SerializerContext context);
  T denormalize<T>(dynamic data, SerializerContext context);
  bool supportsDenormalization<T>(dynamic data, SerializerContext context);
}

abstract class SerializerAware {
  void setSerializer(Serializer serializer);
}

abstract class Encoder {
  String encode(dynamic data, String format, SerializerContext context);
  bool supportsEncoding(String format, [SerializerContext? context]);
  dynamic decode(String data, String format, [SerializerContext? context]);
  bool supportsDecoding(String format, [SerializerContext? context]);
}

class _TransformerCache {
  final Map<Type, Transformer> _normalizationCache = {};
  final Map<Type, Transformer> _denormalizationCache = {};
  final List<Transformer> _transformers;

  _TransformerCache(this._transformers);

  Transformer? findForNormalization<T>(T object, SerializerContext context) {
    final type = T == dynamic ? object.runtimeType : T;

    var transformer = _normalizationCache[type];
    if (transformer != null &&
        transformer.supportsNormalization<T>(object, context)) {
      return transformer;
    }

    for (final t in _transformers) {
      if (t.supportsNormalization<T>(object, context)) {
        _normalizationCache[type] = t;
        return t;
      }
    }

    return null;
  }

  Transformer? findForDenormalization<T>(
    dynamic data,
    SerializerContext context,
  ) {
    var transformer = _denormalizationCache[T];
    if (transformer != null &&
        transformer.supportsDenormalization<T>(data, context)) {
      return transformer;
    }

    for (final t in _transformers) {
      if (t.supportsDenormalization<T>(data, context)) {
        _denormalizationCache[T] = t;
        return t;
      }
    }

    return null;
  }

  void clear() {
    _normalizationCache.clear();
    _denormalizationCache.clear();
  }
}

class _EncoderCache {
  final Map<String, Encoder> _encodingCache = {};
  final Map<String, Encoder> _decodingCache = {};
  final List<Encoder> _encoders;

  _EncoderCache(this._encoders);

  Encoder? findForEncoding(String format, SerializerContext context) {
    final key = format.toLowerCase();
    var encoder = _encodingCache[key];

    if (encoder != null && encoder.supportsEncoding(format, context)) {
      return encoder;
    }

    for (final e in _encoders) {
      if (e.supportsEncoding(format, context)) {
        _encodingCache[key] = e;
        return e;
      }
    }

    return null;
  }

  Encoder? findForDecoding(String format, SerializerContext context) {
    final key = format.toLowerCase();
    var encoder = _decodingCache[key];

    if (encoder != null && encoder.supportsDecoding(format, context)) {
      return encoder;
    }

    for (final e in _encoders) {
      if (e.supportsDecoding(format, context)) {
        _decodingCache[key] = e;
        return e;
      }
    }

    return null;
  }

  void clear() {
    _encodingCache.clear();
    _decodingCache.clear();
  }
}

class _SerializerImpl implements Serializer {
  final _TransformerCache _transformerCache;
  final _EncoderCache _encoderCache;

  _SerializerImpl(List<Transformer> transformers, List<Encoder> encoders)
    : _transformerCache = _TransformerCache(transformers),
      _encoderCache = _EncoderCache(encoders) {
    for (final transformer in transformers) {
      if (transformer is SerializerAware) {
        (transformer as SerializerAware).setSerializer(this);
      }
    }
  }

  @override
  String serialize<T>(T object, String format, [SerializerContext? context]) {
    final normalizedData = normalize<T>(object, context);
    return encode(normalizedData, format, context);
  }

  @override
  T? deserialize<T>(String data, String format, [SerializerContext? context]) {
    final decodedData = decode(data, format, context);
    return denormalize<T>(decodedData, context);
  }

  @override
  dynamic normalize<T>(T object, [SerializerContext? context]) {
    if (object == null) return null;

    final ctx = context ?? SerializerContext();
    final transformer = _transformerCache.findForNormalization<T>(object, ctx);

    if (transformer != null) {
      return transformer.normalize<T>(object, ctx);
    }

    throw SerializerException(
      'No transformer found for normalizing object of type: $T value ($object)',
    );
  }

  @override
  T? denormalize<T>(dynamic data, [SerializerContext? context]) {
    if (data == null) return null;

    final ctx = context ?? SerializerContext();
    final transformer = _transformerCache.findForDenormalization<T>(data, ctx);

    if (transformer != null) {
      return transformer.denormalize<T>(data, ctx);
    }

    throw SerializerException(
      'No transformer found for denormalizing data to type: $T value $data',
    );
  }

  @override
  String encode(dynamic data, String format, [SerializerContext? context]) {
    final ctx = context ?? SerializerContext();
    final encoder = _encoderCache.findForEncoding(format, ctx);

    if (encoder != null) {
      return encoder.encode(data, format, ctx);
    }

    throw SerializerException('No encoder found for format: $format');
  }

  @override
  dynamic decode(String data, String format, [SerializerContext? context]) {
    final ctx = context ?? SerializerContext();
    final encoder = _encoderCache.findForDecoding(format, ctx);

    if (encoder != null) {
      return encoder.decode(data, format, ctx);
    }

    throw SerializerException('No decoder found for format: $format');
  }
}

class JsonEncoder implements Encoder {
  c.JsonEncoder? _prettyEncoder;

  @override
  decode(String data, String format, [SerializerContext? context]) {
    return c.json.decode(data);
  }

  @override
  String encode(data, String format, [SerializerContext? context]) {
    if (context?.pretty == true) {
      _prettyEncoder ??= c.JsonEncoder.withIndent('  ');
      return _prettyEncoder!.convert(data);
    }
    return c.json.encode(data);
  }

  @override
  bool supportsDecoding(String format, [SerializerContext? context]) {
    return format.toLowerCase() == 'json';
  }

  @override
  bool supportsEncoding(String format, [SerializerContext? context]) {
    return format.toLowerCase() == 'json';
  }
}

class PrimitiveTransformer implements Transformer {
  static final _primitiveTypes = {int, double, num, String, bool, DateTime};

  @override
  bool supportsNormalization<T>(T object, SerializerContext context) {
    return _primitiveTypes.contains(T) ||
        object == null ||
        _primitiveTypes.contains(object.runtimeType);
  }

  @override
  bool supportsDenormalization<T>(dynamic data, SerializerContext context) {
    return _primitiveTypes.contains(T) ||
        (_primitiveTypes.contains(data.runtimeType) && T == dynamic);
  }

  @override
  dynamic normalize<T>(T object, SerializerContext context) {
    if (object == null) return null;
    if (object is DateTime) return object.toIso8601String();
    return object;
  }

  @override
  T denormalize<T>(dynamic data, SerializerContext context) {
    if (data == null) return null as T;

    if (T == DateTime) {
      if (data is DateTime) return data as T;
      if (data is String) return DateTime.parse(data) as T;
      if (data is int) return DateTime.fromMillisecondsSinceEpoch(data) as T;
    }

    if (T == String) return data.toString() as T;

    if (T == int) {
      if (data is int) return data as T;
      if (data is num) return data.toInt() as T;
      if (data is String) return int.parse(data) as T;
    }

    if (T == double) {
      if (data is double) return data as T;
      if (data is num) return data.toDouble() as T;
      if (data is String) return double.parse(data) as T;
    }

    if (T == bool) {
      if (data is bool) return data as T;
      if (data is String) {
        return (data.toLowerCase() == 'true' || data == '1') as T;
      }
      if (data is num) return (data != 0) as T;
    }

    return data as T;
  }
}

class ListTransformer implements Transformer, SerializerAware {
  late Serializer _serializer;

  static final _primitiveTypes = {int, double, num, String, bool, DateTime};

  @override
  void setSerializer(Serializer serializer) {
    _serializer = serializer;
  }

  @override
  bool supportsNormalization<T>(T object, SerializerContext context) {
    return <T>[] is List<List> && object is List;
  }

  @override
  bool supportsDenormalization<T>(dynamic data, SerializerContext context) {
    // Suporta listas de tipos primitivos
    if (<T>[] is List<List> && data is List) {
      // Verifica se é uma lista de primitivos
      if (_isListOfPrimitives<T>()) {
        return true;
      }
    }
    return false;
  }

  bool _isListOfPrimitives<T>() {
    // Checa se T é List<PrimitiveType>
    for (final primitiveType in _primitiveTypes) {
      if (_checkListType<T>(primitiveType)) {
        return true;
      }
    }
    return false;
  }

  bool _checkListType<T>(Type primitiveType) {
    if (primitiveType == int) return <T>[] is List<List<int>>;
    if (primitiveType == double) return <T>[] is List<List<double>>;
    if (primitiveType == num) return <T>[] is List<List<num>>;
    if (primitiveType == String) return <T>[] is List<List<String>>;
    if (primitiveType == bool) return <T>[] is List<List<bool>>;
    if (primitiveType == DateTime) return <T>[] is List<List<DateTime>>;
    return false;
  }

  @override
  dynamic normalize<T>(T object, SerializerContext context) {
    if (object is! List) {
      throw SerializerException(
        'ListTransformer can only normalize List objects, got ${object.runtimeType}',
      );
    }

    if (object.isEmpty) return [];

    final result = List<dynamic>.filled(object.length, null, growable: false);

    for (var i = 0; i < object.length; i++) {
      final item = object[i];
      result[i] = item == null ? null : _serializer.normalize(item, context);
    }

    return result;
  }

  @override
  T denormalize<T>(dynamic data, SerializerContext context) {
    if (data is! List) {
      throw SerializerException('Esperava List, recebeu ${data.runtimeType}');
    }

    final itemType = _extractItemTypeFromT(T);
    final denormalized = data.map(
      (e) => _serializer.denormalize<dynamic>(e, context),
    );

    return switch (itemType) {
      'String' => denormalized.cast<String>().toList() as T,
      'int' => denormalized.cast<int>().toList() as T,
      'double' => denormalized.cast<double>().toList() as T,
      'bool' => denormalized.cast<bool>().toList() as T,
      'DateTime' => denormalized.cast<DateTime>().toList() as T,
      _ => denormalized.toList() as T,
    };
  }

  String? _extractItemTypeFromT(Type t) {
    final typeString = t.toString();
    final regex = RegExp(r'List<(.+)>');
    final match = regex.firstMatch(typeString);
    if (match != null && match.groupCount == 1) {
      final itemTypeString = match.group(1);
      switch (itemTypeString) {
        case 'String':
        case 'int':
        case 'double':
        case 'bool':
        case 'DateTime':
          return itemTypeString;
        default:
          return null;
      }
    }
    return null;
  }
}

class MapTransformer implements Transformer, SerializerAware {
  late Serializer _serializer;

  @override
  void setSerializer(Serializer serializer) {
    _serializer = serializer;
  }

  @override
  bool supportsNormalization<T>(T object, SerializerContext context) {
    return object is Map;
  }

  @override
  bool supportsDenormalization<T>(dynamic data, SerializerContext context) {
    return (isSameType<T, Map>() || isSameType<T, Map?>() || T == dynamic) &&
        data is Map;
  }

  @override
  dynamic normalize<T>(T object, SerializerContext context) {
    if (object is! Map) {
      throw SerializerException(
        'MapTransformer can only normalize Map objects, got ${object.runtimeType}',
      );
    }

    if (object.isEmpty) {
      return {};
    }

    final result = <dynamic, dynamic>{};

    for (final entry in object.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value == null && context.omitNull) {
        continue;
      }

      result[_serializer.normalize(key, context)] = _serializer.normalize(
        value,
        context,
      );
    }

    return result;
  }

  @override
  T denormalize<T>(dynamic data, SerializerContext context) {
    if (data is! Map) {
      throw SerializerException(
        'MapTransformer can only denormalize Map data, got ${data.runtimeType}',
      );
    }

    if (data.isEmpty) {
      return <dynamic, dynamic>{} as T;
    }

    final result = <dynamic, dynamic>{};

    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;

      result[_serializer.denormalize<dynamic>(key, context)] = _serializer
          .denormalize<dynamic>(value, context);
    }

    return result as T;
  }
}

import 'package:meta/meta_meta.dart';

import '../../forge_core.dart';

@Target({TargetKind.classType, TargetKind.enumType})
class Mappable
    implements DeclarationsCapability, EnumCapability, EnumValuesCapability {
  const Mappable();
}

@Target({TargetKind.field, TargetKind.getter, TargetKind.method})
class Ignore {
  const Ignore();
}

@Target({TargetKind.field, TargetKind.getter, TargetKind.method})
class Property {
  final String? name;
  final bool? omitIfNull;
  final List<String>? groups;

  const Property({this.name, this.omitIfNull, this.groups});
}

@Target({TargetKind.enumType})
class EnumExtractor {
  final String fieldName;

  const EnumExtractor(this.fieldName);
}

@Target({TargetKind.field, TargetKind.getter})
class EnumDelimiter {
  final String delimiter;

  const EnumDelimiter(this.delimiter);
}

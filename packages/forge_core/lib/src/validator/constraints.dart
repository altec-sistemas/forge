import 'package:cpf_cnpj_validator/cnpj_validator.dart';
import 'package:cpf_cnpj_validator/cpf_validator.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:meta/meta_meta.dart';
import 'validator.dart';
import 'message_provider.dart';

/// Validates a collection with constraints per field
@Target({TargetKind.getter, TargetKind.field})
class Collection extends Constraint {
  final Map<String, Constraint> fields;
  final bool allowExtraFields;
  final bool allowMissingFields;
  final String? nullMessage;
  final String? invalidTypeMessage;
  final String? fieldRequiredMessage;
  final String? fieldNotAllowedMessage;

  const Collection(
    this.fields, {
    this.allowExtraFields = false,
    this.allowMissingFields = false,
    this.nullMessage,
    this.invalidTypeMessage,
    this.fieldRequiredMessage,
    this.fieldNotAllowedMessage,
  });

  @override
  void validate(dynamic value, ValidationContext context) {
    if (value == null) {
      context.addViolation(
        ValidationMessageKey.notNull,
        message: nullMessage,
        value: value,
      );
      return;
    }

    if (value is! Map) {
      context.addViolation(
        ValidationMessageKey.mustBeMap,
        message: invalidTypeMessage,
        value: value,
      );
      return;
    }

    final data = Map<String, dynamic>.from(value);

    for (final entry in fields.entries) {
      final fieldName = entry.key;
      final constraint = entry.value;
      final fieldValue = data[fieldName];

      if (!data.containsKey(fieldName)) {
        if (constraint is Optional || allowMissingFields) {
          continue;
        }

        final fieldContext = context.atPath(fieldName);
        fieldContext.addViolation(
          ValidationMessageKey.fieldRequired,
          message: fieldRequiredMessage,
        );
        continue;
      }

      final fieldContext = context.atPath(fieldName);
      constraint.validate(fieldValue, fieldContext);
    }

    if (!allowExtraFields) {
      for (final key in data.keys) {
        if (!fields.containsKey(key)) {
          final fieldContext = context.atPath(key);
          fieldContext.addViolation(
            ValidationMessageKey.fieldNotAllowed,
            message: fieldNotAllowedMessage,
          );
        }
      }
    }
  }
}

/// Applies multiple constraints to the same value
@Target({TargetKind.getter, TargetKind.field})
class All extends Constraint {
  final List<Constraint> constraints;

  const All(this.constraints);

  @override
  void validate(dynamic value, ValidationContext context) {
    for (final constraint in constraints) {
      constraint.validate(value, context);
    }
  }
}

/// Marks a field as optional (field can be null or missing)
@Target({TargetKind.getter, TargetKind.field})
class Optional extends Constraint {
  final Constraint constraint;

  const Optional(this.constraint);

  factory Optional.all(List<Constraint> constraints) =>
      Optional(All(constraints));
  factory Optional.allEach(List<Constraint> constraints) =>
      Optional(Each.all(constraints));

  @override
  void validate(dynamic value, ValidationContext context) {
    if (value == null) return;
    constraint.validate(value, context);
  }
}

const notBlank = NotBlank();

/// Validates that the value is not blank
@Target({TargetKind.getter, TargetKind.field})
class NotBlank extends Constraint {
  final String? message;

  const NotBlank({this.message});

  @override
  void validate(dynamic value, ValidationContext context) {
    if (value is! String &&
        value is! num &&
        value is! List &&
        value is! Map &&
        value != null) {
      return;
    }

    bool fail = false;

    if (value == null) {
      fail = true;
    } else if (value is String && value.trim().isEmpty) {
      fail = true;
    } else if (value is List && value.isEmpty) {
      fail = true;
    } else if (value is Map && value.isEmpty) {
      fail = true;
    } else if (value is num && value == 0) {
      fail = true;
    }

    if (fail) {
      context.addViolation(
        ValidationMessageKey.notBlank,
        message: message,
        value: value,
      );
    }
  }
}

const notNull = NotNull();

/// Validates that the value is not null
@Target({TargetKind.getter, TargetKind.field})
class NotNull extends Constraint {
  final String? message;

  const NotNull({this.message});

  @override
  void validate(dynamic value, ValidationContext context) {
    if (value == null) {
      context.addViolation(
        ValidationMessageKey.notNull,
        message: message,
        value: value,
      );
    }
  }
}

/// Validates the length of a string
@Target({TargetKind.getter, TargetKind.field})
class Length extends Constraint {
  final int? min;
  final int? max;
  final String? minMessage;
  final String? maxMessage;

  const Length({
    this.min,
    this.max,
    this.minMessage,
    this.maxMessage,
  });

  @override
  void validate(dynamic value, ValidationContext context) {
    if (value is! String) return;

    final length = value.length;

    if (min != null && length < min!) {
      context.addViolation(
        ValidationMessageKey.minLength,
        message: minMessage,
        value: value,
        params: {'min': min},
      );
    }

    if (max != null && length > max!) {
      context.addViolation(
        ValidationMessageKey.maxLength,
        message: maxMessage,
        value: value,
        params: {'max': max},
      );
    }
  }
}

const email = Email();

/// Validates email format
@Target({TargetKind.getter, TargetKind.field})
class Email extends Constraint {
  final String? message;

  const Email({this.message});

  static const String email =
      r'''(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*|"(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21\x23-\x5b\x5d-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])*")@(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\[(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21-\x5a\x53-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])+)\])''';

  @override
  void validate(dynamic value, ValidationContext context) {
    if (value is! String) return;
    if (value.isEmpty) return;

    final regex = RegExp(email);

    if (!regex.hasMatch(value)) {
      context.addViolation(
        ValidationMessageKey.invalidEmail,
        message: message,
        value: value,
      );
    }
  }
}

/// Validates numeric range
@Target({TargetKind.getter, TargetKind.field})
class Range extends Constraint {
  final num? min;
  final num? max;
  final String? minMessage;
  final String? maxMessage;

  const Range({
    this.min,
    this.max,
    this.minMessage,
    this.maxMessage,
  });

  @override
  void validate(dynamic value, ValidationContext context) {
    if (value is! num) return;

    if (min != null && value < min!) {
      context.addViolation(
        ValidationMessageKey.minValue,
        message: minMessage,
        value: value,
        params: {'min': min},
      );
    }

    if (max != null && value > max!) {
      context.addViolation(
        ValidationMessageKey.maxValue,
        message: maxMessage,
        value: value,
        params: {'max': max},
      );
    }
  }
}

/// Validates against a regular expression
@Target({TargetKind.getter, TargetKind.field})
class Regex extends Constraint {
  final String pattern;
  final String? message;

  const Regex(this.pattern, {this.message});

  @override
  void validate(dynamic value, ValidationContext context) {
    if (value is! String) return;
    if (value.isEmpty) return;

    final regex = RegExp(pattern);
    if (!regex.hasMatch(value)) {
      context.addViolation(
        ValidationMessageKey.invalidFormat,
        message: message,
        value: value,
      );
    }
  }
}

/// Validates if the value is in a list of options
@Target({TargetKind.getter, TargetKind.field})
class Choice extends Constraint {
  final List<dynamic> choices;
  final String? message;

  const Choice(this.choices, {this.message});

  @override
  void validate(dynamic value, ValidationContext context) {
    if (value == null) return;

    if (!choices.contains(value)) {
      context.addViolation(
        ValidationMessageKey.invalidChoice,
        message: message,
        value: value,
        params: {'choices': choices.join(', ')},
      );
    }
  }
}

const isString = IsString();

/// Validates that the value is a String
@Target({TargetKind.getter, TargetKind.field})
class IsString extends Constraint {
  final String? message;

  const IsString({this.message});

  @override
  void validate(dynamic value, ValidationContext context) {
    if (value is! String) {
      context.addViolation(
        ValidationMessageKey.mustBeString,
        message: message,
        value: value,
      );
    }
  }
}

const isNum = IsNum();

/// Validates that the value is a num
@Target({TargetKind.getter, TargetKind.field})
class IsNum extends Constraint {
  final String? message;

  const IsNum({this.message});

  @override
  void validate(dynamic value, ValidationContext context) {
    if (value is! num) {
      context.addViolation(
        ValidationMessageKey.mustBeNum,
        message: message,
        value: value,
      );
    }
  }
}

const isInt = IsInt();

/// Validates that the value is an int
@Target({TargetKind.getter, TargetKind.field})
class IsInt extends Constraint {
  final String? message;

  const IsInt({this.message});

  @override
  void validate(dynamic value, ValidationContext context) {
    if (value is! int) {
      context.addViolation(
        ValidationMessageKey.mustBeInt,
        message: message,
        value: value,
      );
    }
  }
}

const isDouble = IsDouble();

/// Validates that the value is a double
@Target({TargetKind.getter, TargetKind.field})
class IsDouble extends Constraint {
  final String? message;

  const IsDouble({this.message});

  @override
  void validate(dynamic value, ValidationContext context) {
    if (value is! double) {
      context.addViolation(
        ValidationMessageKey.mustBeDouble,
        message: message,
        value: value,
      );
    }
  }
}

const isBool = IsBool();

/// Validates that the value is a bool
@Target({TargetKind.getter, TargetKind.field})
class IsBool extends Constraint {
  final String? message;

  const IsBool({this.message});

  @override
  void validate(dynamic value, ValidationContext context) {
    if (value is! bool) {
      context.addViolation(
        ValidationMessageKey.mustBeBool,
        message: message,
        value: value,
      );
    }
  }
}

const isList = IsList();

/// Validates that the value is a List
@Target({TargetKind.getter, TargetKind.field})
class IsList extends Constraint {
  final String? message;

  const IsList({this.message});

  @override
  void validate(dynamic value, ValidationContext context) {
    if (value is! List) {
      context.addViolation(
        ValidationMessageKey.mustBeList,
        message: message,
        value: value,
      );
    }
  }
}

/// Validates each element of a list with a constraint
@Target({TargetKind.getter, TargetKind.field})
class Each extends Constraint {
  final Constraint constraint;

  const Each(this.constraint);

  factory Each.all(List<Constraint> constraints) => Each(All(constraints));

  @override
  void validate(dynamic value, ValidationContext context) {
    if (value is! List) return;

    for (var i = 0; i < value.length; i++) {
      final itemContext = context.atIndex(i);
      constraint.validate(value[i], itemContext);
    }
  }
}

const cpf = Cpf();

/// Validates CPF (Brazilian tax ID for individuals)
@Target({TargetKind.getter, TargetKind.field})
class Cpf extends Constraint {
  final String? message;

  const Cpf({this.message});

  @override
  void validate(dynamic value, ValidationContext context) {
    if (value == null) return;
    if (value is! String) return;

    final cleanValue = value.replaceAll(RegExp(r'[^\d]'), '');

    if (cleanValue.isEmpty) return;

    if (!CPFValidator.isValid(cleanValue)) {
      context.addViolation(
        ValidationMessageKey.cpfInvalid,
        message: message,
        value: value,
      );
    }
  }
}

const cnpj = Cnpj();

/// Validates CNPJ (Brazilian tax ID for companies)
@Target({TargetKind.getter, TargetKind.field})
class Cnpj extends Constraint {
  final String? message;

  const Cnpj({this.message});

  @override
  void validate(dynamic value, ValidationContext context) {
    if (value == null) return;
    if (value is! String) return;

    final cleanValue = value.replaceAll(RegExp(r'[^\d]'), '');

    if (cleanValue.isEmpty) return;

    if (!CNPJValidator.isValid(cleanValue)) {
      context.addViolation(
        ValidationMessageKey.cnpjInvalid,
        message: message,
        value: value,
      );
    }
  }
}

const cpfOrCnpj = CpfOrCnpj();

/// Validates CPF or CNPJ (Brazilian tax IDs)
/// Accepts either a valid CPF (11 digits) or CNPJ (14 digits)
@Target({TargetKind.getter, TargetKind.field})
class CpfOrCnpj extends Constraint {
  final String? message;

  const CpfOrCnpj({this.message});

  @override
  void validate(dynamic value, ValidationContext context) {
    if (value == null) return;
    if (value is! String) return;

    final cleanValue = value.replaceAll(RegExp(r'[^\d]'), '');

    if (cleanValue.isEmpty) return;

    if (cleanValue.contains(RegExp(r'\D'))) {
      context.addViolation(
        ValidationMessageKey.cpfOrCnpjOnlyDigits,
        value: value,
      );
      return;
    }

    if (CNPJValidator.isValid(value) || CPFValidator.isValid(value)) {
      return;
    }

    context.addViolation(
      ValidationMessageKey.cpfOrCnpjInvalid,
      message: message,
      value: value,
    );
  }
}

const phone = Phone();

/// Validates phone number using phone_numbers_parser
///
/// Requires: phone_numbers_parser package
/// Add to pubspec.yaml: phone_numbers_parser: ^8.3.0
@Target({TargetKind.getter, TargetKind.field})
class Phone extends Constraint {
  final String? isoCode;
  final String? message;

  const Phone({this.isoCode = 'US', this.message});

  @override
  void validate(dynamic value, ValidationContext context) {
    if (value == null) return;
    if (value is! String) return;
    if (value.trim().isEmpty) return;

    try {
      // Remove all non-digit characters for parsing
      final cleanValue = value.replaceAll(RegExp(r'[^\d]'), '');

      // Parse the phone number
      final phoneNumber = PhoneNumber.parse(
        cleanValue,
        callerCountry: IsoCode.fromJson(isoCode ?? 'BR'),
      );

      // Validate the parsed number
      if (!phoneNumber.isValid()) {
        context.addViolation(
          ValidationMessageKey.phoneInvalid,
          message: message,
          value: value,
        );
      }
    } catch (e) {
      context.addViolation(
        ValidationMessageKey.phoneInvalid,
        message: message,
        value: value,
      );
    }
  }
}

/// Validates birth date with optional age constraints
@Target({TargetKind.getter, TargetKind.field})
class BirthDate extends Constraint {
  final int? minAge;
  final int? maxAge;
  final String? message;

  const BirthDate({this.minAge, this.maxAge, this.message});

  @override
  void validate(dynamic value, ValidationContext context) {
    if (value == null) return;
    if (value is! DateTime) return;

    final now = DateTime.now();

    if (value.isAfter(now)) {
      context.addViolation(
        ValidationMessageKey.birthDateFuture,
        value: value,
      );
      return;
    }

    int age = now.year - value.year;
    if (now.month < value.month ||
        (now.month == value.month && now.day < value.day)) {
      age--;
    }

    if (minAge != null && age < minAge!) {
      context.addViolation(
        ValidationMessageKey.birthDateMinAge,
        value: value,
        params: {'minAge': minAge},
      );
    }

    if (maxAge != null && age > maxAge!) {
      context.addViolation(
        ValidationMessageKey.birthDateMaxAge,
        value: value,
        params: {'maxAge': maxAge},
      );
    }
  }
}

const pastDate = PastDate();

/// Validates that date is in the past
@Target({TargetKind.getter, TargetKind.field})
class PastDate extends Constraint {
  final bool allowToday;
  final String? message;

  const PastDate({this.allowToday = true, this.message});

  @override
  void validate(dynamic value, ValidationContext context) {
    if (value == null) return;
    if (value is! DateTime) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateToCheck = DateTime(value.year, value.month, value.day);

    if (allowToday) {
      if (dateToCheck.isAfter(today)) {
        context.addViolation(
          ValidationMessageKey.pastDateOrToday,
          message: message,
          value: value,
        );
      }
    } else {
      if (dateToCheck.isAfter(today) || dateToCheck.isAtSameMomentAs(today)) {
        context.addViolation(
          ValidationMessageKey.pastDate,
          message: message,
          value: value,
        );
      }
    }
  }
}

const futureDate = FutureDate();

/// Validates that date is in the future
@Target({TargetKind.getter, TargetKind.field})
class FutureDate extends Constraint {
  final bool allowToday;
  final String? message;

  const FutureDate({this.allowToday = true, this.message});

  @override
  void validate(dynamic value, ValidationContext context) {
    if (value == null) return;
    if (value is! DateTime) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateToCheck = DateTime(value.year, value.month, value.day);

    if (allowToday) {
      if (dateToCheck.isBefore(today)) {
        context.addViolation(
          ValidationMessageKey.futureDateOrToday,
          message: message,
          value: value,
        );
      }
    } else {
      if (dateToCheck.isBefore(today) || dateToCheck.isAtSameMomentAs(today)) {
        context.addViolation(
          ValidationMessageKey.futureDate,
          message: message,
          value: value,
        );
      }
    }
  }
}

/// Validates date range
@Target({TargetKind.getter, TargetKind.field})
class DateRange extends Constraint {
  final DateTime? min;
  final DateTime? max;
  final bool minInclusive;
  final bool maxInclusive;
  final String? message;

  const DateRange({
    this.min,
    this.max,
    this.minInclusive = true,
    this.maxInclusive = true,
    this.message,
  });

  @override
  void validate(dynamic value, ValidationContext context) {
    if (value == null) return;

    DateTime? dateValue;
    if (value is DateTime) {
      dateValue = value;
    } else if (value is String) {
      dateValue = DateTime.tryParse(value);
    }

    if (dateValue == null) return;

    if (min != null) {
      final isValid = minInclusive
          ? dateValue.isAfter(min!) || dateValue.isAtSameMomentAs(min!)
          : dateValue.isAfter(min!);

      if (!isValid) {
        final key = minInclusive
            ? ValidationMessageKey.dateRangeMinInclusive
            : ValidationMessageKey.dateRangeMinExclusive;
        context.addViolation(
          key,
          value: value,
          params: {'min': min!.toIso8601String().split('T')[0]},
        );
      }
    }

    if (max != null) {
      final isValid = maxInclusive
          ? dateValue.isBefore(max!) || dateValue.isAtSameMomentAs(max!)
          : dateValue.isBefore(max!);

      if (!isValid) {
        final key = maxInclusive
            ? ValidationMessageKey.dateRangeMaxInclusive
            : ValidationMessageKey.dateRangeMaxExclusive;
        context.addViolation(
          key,
          value: value,
          params: {'max': max!.toIso8601String().split('T')[0]},
        );
      }
    }
  }
}

/// Validates value is greater than a threshold
@Target({TargetKind.getter, TargetKind.field})
class GreaterThan extends Constraint {
  final num minExclusive;
  final String? message;

  const GreaterThan(this.minExclusive, {this.message});

  @override
  void validate(dynamic value, ValidationContext context) {
    if (value == null) return;
    if (value is! num) return;

    if (value <= minExclusive) {
      context.addViolation(
        ValidationMessageKey.greaterThan,
        message: message,
        value: value,
        params: {'min': minExclusive},
      );
    }
  }
}

/// Validates value is greater than or equal to a threshold
@Target({TargetKind.getter, TargetKind.field})
class GreaterOrEqual extends Constraint {
  final num minInclusive;
  final String? message;

  const GreaterOrEqual(this.minInclusive, {this.message});

  @override
  void validate(dynamic value, ValidationContext context) {
    if (value == null) return;
    if (value is! num) return;

    if (value < minInclusive) {
      context.addViolation(
        ValidationMessageKey.greaterOrEqual,
        message: message,
        value: value,
        params: {'min': minInclusive},
      );
    }
  }
}

/// Validates value is less than a threshold
@Target({TargetKind.getter, TargetKind.field})
class LessThan extends Constraint {
  final num maxExclusive;
  final String? message;

  const LessThan(this.maxExclusive, {this.message});

  @override
  void validate(dynamic value, ValidationContext context) {
    if (value == null) return;
    if (value is! num) return;

    if (value >= maxExclusive) {
      context.addViolation(
        ValidationMessageKey.lessThan,
        message: message,
        value: value,
        params: {'max': maxExclusive},
      );
    }
  }
}

/// Validates value is less than or equal to a threshold
@Target({TargetKind.getter, TargetKind.field})
class LessOrEqual extends Constraint {
  final num maxInclusive;
  final String? message;

  const LessOrEqual(this.maxInclusive, {this.message});

  @override
  void validate(dynamic value, ValidationContext context) {
    if (value == null) return;
    if (value is! num) return;

    if (value > maxInclusive) {
      context.addViolation(
        ValidationMessageKey.lessOrEqual,
        message: message,
        value: value,
        params: {'max': maxInclusive},
      );
    }
  }
}

const md5 = Md5();

/// Validates MD5 hash format
@Target({TargetKind.getter, TargetKind.field})
class Md5 extends Constraint {
  final String? message;

  const Md5({this.message});

  @override
  void validate(dynamic value, ValidationContext context) {
    if (value == null) return;
    if (value is! String) return;

    final normalized = value.trim();
    final hex32 = RegExp(r'^[a-fA-F0-9]{32}$');

    if (!hex32.hasMatch(normalized)) {
      context.addViolation(
        ValidationMessageKey.md5Invalid,
        message: message,
        value: value,
      );
    }
  }
}

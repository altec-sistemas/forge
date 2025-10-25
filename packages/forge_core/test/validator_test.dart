import 'package:forge_core/forge_core.dart';
import 'package:forge_core/src/validator/brazilian_document/cnpj_validator.dart';
import 'package:forge_core/src/validator/brazilian_document/cpf_validator.dart';
import 'package:test/test.dart';

void main() {
  group('Validator - Basic Operations', () {
    test('should create validator instance', () {
      final validator = Validator();
      expect(validator, isA<Validator>());
    });

    test('should create validator with custom message provider', () {
      final validator = Validator(PortugueseValidationMessageProvider());
      expect(validator, isA<Validator>());
    });

    test('validate should return empty list for valid data', () {
      final validator = Validator();
      final violations = validator.validate('test', notBlank);
      expect(violations, isEmpty);
    });

    test('validate should return violations for invalid data', () {
      final validator = Validator();
      final violations = validator.validate(null, notNull);
      expect(violations, isNotEmpty);
      expect(violations.first.message, contains('should not be null'));
    });

    test('isValid should return true for valid data', () {
      final validator = Validator();
      expect(validator.isValid('test', notBlank), isTrue);
    });

    test('isValid should return false for invalid data', () {
      final validator = Validator();
      expect(validator.isValid(null, notNull), isFalse);
    });

    test('validateOrThrow should not throw for valid data', () {
      final validator = Validator();
      expect(
        () => validator.validateOrThrow('test', notBlank),
        returnsNormally,
      );
    });

    test('validateOrThrow should throw for invalid data', () {
      final validator = Validator();
      expect(
        () => validator.validateOrThrow(null, notNull),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('ValidationContext', () {
    test('should create context with empty path', () {
      final context = ValidationContext();
      expect(context.propertyPath, isEmpty);
      expect(context.isValid, isTrue);
    });

    test('should create context with initial path', () {
      final context = ValidationContext('user.name');
      expect(context.propertyPath, equals('user.name'));
    });

    test('addViolation should add violation to context', () {
      final context = ValidationContext();
      context.addViolation(ValidationMessageKey.notNull, value: null);

      expect(context.hasViolations, isTrue);
      expect(context.violations, hasLength(1));
    });

    test('addViolation with custom message should use custom message', () {
      final context = ValidationContext();
      context.addViolation(
        ValidationMessageKey.notNull,
        message: 'Custom error message',
        value: null,
      );

      expect(context.violations.first.message, equals('Custom error message'));
    });

    test('addViolationAt should add violation with custom path', () {
      final context = ValidationContext('user');
      context.addViolationAt('email', ValidationMessageKey.invalidEmail);

      expect(context.violations.first.propertyPath, equals('email'));
    });

    test('atPath should create nested context', () {
      final context = ValidationContext('user');
      final nestedContext = context.atPath('address');

      expect(nestedContext.propertyPath, equals('user.address'));
    });

    test('atIndex should create array context', () {
      final context = ValidationContext('users');
      final indexContext = context.atIndex(0);

      expect(indexContext.propertyPath, equals('users.[0]'));
    });

    test('nested violations should accumulate', () {
      final context = ValidationContext('root');
      context.addViolation(ValidationMessageKey.notNull);

      final nested = context.atPath('child');
      nested.addViolation(ValidationMessageKey.notBlank);

      expect(nested.violations, hasLength(2));
    });
  });

  group('ValidationException', () {
    test('should create exception with violations', () {
      final violations = [
        Violation('name', 'Name is required'),
        Violation('email', 'Invalid email'),
      ];
      final exception = ValidationException(violations);

      expect(exception.violations, hasLength(2));
    });

    test('toString should format violations', () {
      final violations = [
        Violation('name', 'Name is required'),
      ];
      final exception = ValidationException(violations);

      expect(exception.toString(), contains('name'));
      expect(exception.toString(), contains('Name is required'));
    });

    test('byField should group violations by field', () {
      final violations = [
        Violation('name', 'Required'),
        Violation('name', 'Too short'),
        Violation('email', 'Invalid'),
      ];
      final exception = ValidationException(violations);
      final byField = exception.byField;

      expect(byField['name'], hasLength(2));
      expect(byField['email'], hasLength(1));
    });

    test('empty violations should have descriptive toString', () {
      final exception = ValidationException([]);
      expect(exception.toString(), contains('No violations'));
    });
  });

  group('Constraint - NotNull', () {
    test('should pass for non-null values', () {
      final validator = Validator();
      expect(validator.isValid('text', notNull), isTrue);
      expect(validator.isValid(0, notNull), isTrue);
      expect(validator.isValid(false, notNull), isTrue);
      expect(validator.isValid([], notNull), isTrue);
    });

    test('should fail for null value', () {
      final validator = Validator();
      final violations = validator.validate(null, notNull);

      expect(violations, hasLength(1));
      expect(violations.first.message, contains('should not be null'));
    });

    test('should use custom message', () {
      final validator = Validator();
      final constraint = NotNull(message: 'Custom null message');
      final violations = validator.validate(null, constraint);

      expect(violations.first.message, equals('Custom null message'));
    });
  });

  group('Constraint - NotBlank', () {
    test('should pass for non-blank strings', () {
      final validator = Validator();
      expect(validator.isValid('text', notBlank), isTrue);
      expect(validator.isValid('  text  ', notBlank), isTrue);
    });

    test('should fail for null', () {
      final validator = Validator();
      expect(validator.isValid(null, notBlank), isFalse);
    });

    test('should fail for empty string', () {
      final validator = Validator();
      expect(validator.isValid('', notBlank), isFalse);
    });

    test('should fail for whitespace only', () {
      final validator = Validator();
      expect(validator.isValid('   ', notBlank), isFalse);
    });

    test('should fail for empty list', () {
      final validator = Validator();
      expect(validator.isValid([], notBlank), isFalse);
    });

    test('should fail for empty map', () {
      final validator = Validator();
      expect(validator.isValid({}, notBlank), isFalse);
    });

    test('should fail for zero number', () {
      final validator = Validator();
      expect(validator.isValid(0, notBlank), isFalse);
    });

    test('should pass for non-empty list', () {
      final validator = Validator();
      expect(validator.isValid([1, 2], notBlank), isTrue);
    });

    test('should pass for non-empty map', () {
      final validator = Validator();
      expect(validator.isValid({'key': 'value'}, notBlank), isTrue);
    });

    test('should pass for non-zero number', () {
      final validator = Validator();
      expect(validator.isValid(42, notBlank), isTrue);
    });
  });

  group('Constraint - Length', () {
    test('should pass for string within range', () {
      final validator = Validator();
      final constraint = Length(min: 3, max: 10);

      expect(validator.isValid('test', constraint), isTrue);
      expect(validator.isValid('hello', constraint), isTrue);
    });

    test('should fail for string too short', () {
      final validator = Validator();
      final constraint = Length(min: 5);
      final violations = validator.validate('hi', constraint);

      expect(violations, hasLength(1));
      expect(violations.first.message, contains('too short'));
    });

    test('should fail for string too long', () {
      final validator = Validator();
      final constraint = Length(max: 5);
      final violations = validator.validate('too long string', constraint);

      expect(violations, hasLength(1));
      expect(violations.first.message, contains('too long'));
    });

    test('should skip non-string values', () {
      final validator = Validator();
      final constraint = Length(min: 5);
      expect(validator.isValid(123, constraint), isTrue);
    });
  });

  group('Constraint - Email', () {
    test('should pass for valid emails', () {
      final validator = Validator();
      expect(validator.isValid('user@example.com', email), isTrue);
      expect(validator.isValid('test.user@domain.co.uk', email), isTrue);
      expect(validator.isValid('name+tag@site.org', email), isTrue);
    });

    test('should fail for invalid emails', () {
      final validator = Validator();
      expect(validator.isValid('invalid', email), isFalse);
      expect(validator.isValid('@example.com', email), isFalse);
      expect(validator.isValid('user@', email), isFalse);
      expect(validator.isValid('user @example.com', email), isFalse);
    });

    test('should skip empty strings', () {
      final validator = Validator();
      expect(validator.isValid('', email), isTrue);
    });

    test('should skip non-string values', () {
      final validator = Validator();
      expect(validator.isValid(123, email), isTrue);
    });
  });

  group('Constraint - Range', () {
    test('should pass for numbers within range', () {
      final validator = Validator();
      final constraint = Range(min: 0, max: 100);

      expect(validator.isValid(50, constraint), isTrue);
      expect(validator.isValid(0, constraint), isTrue);
      expect(validator.isValid(100, constraint), isTrue);
    });

    test('should fail for numbers below minimum', () {
      final validator = Validator();
      final constraint = Range(min: 10);
      expect(validator.isValid(5, constraint), isFalse);
    });

    test('should fail for numbers above maximum', () {
      final validator = Validator();
      final constraint = Range(max: 100);
      expect(validator.isValid(150, constraint), isFalse);
    });

    test('should work with decimals', () {
      final validator = Validator();
      final constraint = Range(min: 0.5, max: 9.5);

      expect(validator.isValid(5.5, constraint), isTrue);
      expect(validator.isValid(0.3, constraint), isFalse);
      expect(validator.isValid(10.0, constraint), isFalse);
    });
  });

  group('Constraint - Regex', () {
    test('should pass for matching pattern', () {
      final validator = Validator();
      final constraint = Regex(r'^\d{3}-\d{3}$');

      expect(validator.isValid('123-456', constraint), isTrue);
    });

    test('should fail for non-matching pattern', () {
      final validator = Validator();
      final constraint = Regex(r'^\d{3}-\d{3}$');

      expect(validator.isValid('abc-def', constraint), isFalse);
    });

    test('should skip empty strings', () {
      final validator = Validator();
      final constraint = Regex(r'^\d+$');
      expect(validator.isValid('', constraint), isTrue);
    });
  });

  group('Constraint - Choice', () {
    test('should pass for valid choice', () {
      final validator = Validator();
      final constraint = Choice(['red', 'green', 'blue']);

      expect(validator.isValid('red', constraint), isTrue);
      expect(validator.isValid('green', constraint), isTrue);
    });

    test('should fail for invalid choice', () {
      final validator = Validator();
      final constraint = Choice(['red', 'green', 'blue']);

      expect(validator.isValid('yellow', constraint), isFalse);
    });

    test('should skip null values', () {
      final validator = Validator();
      final constraint = Choice(['red', 'green', 'blue']);
      expect(validator.isValid(null, constraint), isTrue);
    });

    test('should work with numbers', () {
      final validator = Validator();
      final constraint = Choice([1, 2, 3]);

      expect(validator.isValid(2, constraint), isTrue);
      expect(validator.isValid(5, constraint), isFalse);
    });
  });

  group('Constraint - Type Validators', () {
    test('IsString should validate strings', () {
      final validator = Validator();
      expect(validator.isValid('text', isString), isTrue);
      expect(validator.isValid(123, isString), isFalse);
    });

    test('IsNum should validate numbers', () {
      final validator = Validator();
      expect(validator.isValid(123, isNum), isTrue);
      expect(validator.isValid(45.6, isNum), isTrue);
      expect(validator.isValid('text', isNum), isFalse);
    });

    test('IsInt should validate integers', () {
      final validator = Validator();
      expect(validator.isValid(123, isInt), isTrue);
      expect(validator.isValid(45.6, isInt), isFalse);
    });

    test('IsDouble should validate doubles', () {
      final validator = Validator();
      expect(validator.isValid(45.6, isDouble), isTrue);
      expect(validator.isValid(123, isDouble), isFalse);
    });

    test('IsBool should validate booleans', () {
      final validator = Validator();
      expect(validator.isValid(true, isBool), isTrue);
      expect(validator.isValid(false, isBool), isTrue);
      expect(validator.isValid(1, isBool), isFalse);
    });

    test('IsList should validate lists', () {
      final validator = Validator();
      expect(validator.isValid([], IsList()), isTrue);
      expect(validator.isValid([1, 2, 3], IsList()), isTrue);
      expect(validator.isValid('text', IsList()), isFalse);
    });
  });

  group('Constraint - All', () {
    test('should apply all constraints', () {
      final validator = Validator();
      final constraint = All([
        notBlank,
        Length(min: 3, max: 10),
      ]);

      expect(validator.isValid('hello', constraint), isTrue);
    });

    test('should fail if any constraint fails', () {
      final validator = Validator();
      final constraint = All([
        notBlank,
        Length(min: 10),
      ]);

      final violations = validator.validate('short', constraint);
      expect(violations, isNotEmpty);
    });

    test('should collect all violations', () {
      final validator = Validator();
      final constraint = All([
        Length(min: 10),
        Length(max: 5),
      ]);

      final violations = validator.validate('medium', constraint);
      expect(violations, hasLength(2));
    });
  });

  group('Constraint - Optional', () {
    test('should skip validation for null', () {
      final validator = Validator();
      final constraint = Optional(Length(min: 5));

      expect(validator.isValid(null, constraint), isTrue);
    });

    test('should validate non-null values', () {
      final validator = Validator();
      final constraint = Optional(Length(min: 5));

      expect(validator.isValid('hello', constraint), isTrue);
      expect(validator.isValid('hi', constraint), isFalse);
    });
  });

  group('Constraint - Each', () {
    test('should validate each element in list', () {
      final validator = Validator();
      final constraint = Each(isString);

      expect(validator.isValid(['a', 'b', 'c'], constraint), isTrue);
    });

    test('should fail if any element is invalid', () {
      final validator = Validator();
      final constraint = Each(isString);

      expect(validator.isValid(['a', 123, 'c'], constraint), isFalse);
    });

    test('should use correct path for violations', () {
      final validator = Validator();
      final constraint = Each(isString);
      final violations = validator.validate(['a', 123, 'c'], constraint);

      expect(violations.first.propertyPath, equals('[1]'));
    });

    test('should skip non-list values', () {
      final validator = Validator();
      final constraint = Each(isString);
      expect(validator.isValid('not a list', constraint), isTrue);
    });
  });

  group('Constraint - Collection', () {
    test('should validate all fields', () {
      final validator = Validator();
      final constraint = Collection({
        'name': notBlank,
        'age': isNum,
      });

      final data = {'name': 'John', 'age': 30};
      expect(validator.isValid(data, constraint), isTrue);
    });

    test('should fail for missing required fields', () {
      final validator = Validator();
      final constraint = Collection({
        'name': notBlank,
        'age': isNum,
      });

      final violations = validator.validate({'name': 'John'}, constraint);
      expect(violations, isNotEmpty);
      expect(violations.first.propertyPath, equals('age'));
    });

    test('should allow missing optional fields', () {
      final validator = Validator();
      final constraint = Collection({
        'name': notBlank,
        'age': Optional(isNum),
      });

      expect(validator.isValid({'name': 'John'}, constraint), isTrue);
    });

    test('should fail for extra fields when not allowed', () {
      final validator = Validator();
      final constraint = Collection({
        'name': notBlank,
      }, allowExtraFields: false);

      final violations = validator.validate({
        'name': 'John',
        'extra': 'field',
      }, constraint);

      expect(violations.any((v) => v.propertyPath == 'extra'), isTrue);
    });

    test('should allow extra fields when configured', () {
      final validator = Validator();
      final constraint = Collection({
        'name': notBlank,
      }, allowExtraFields: true);

      expect(
        validator.isValid({
          'name': 'John',
          'extra': 'field',
        }, constraint),
        isTrue,
      );
    });

    test('should fail for null value', () {
      final validator = Validator();
      final constraint = Collection({'name': notBlank});
      expect(validator.isValid(null, constraint), isFalse);
    });

    test('should fail for non-map value', () {
      final validator = Validator();
      final constraint = Collection({'name': notBlank});
      expect(validator.isValid('not a map', constraint), isFalse);
    });

    test('should use correct nested paths', () {
      final validator = Validator();
      final constraint = Collection({
        'user': Collection({
          'name': notBlank,
        }),
      });

      final violations = validator.validate({
        'user': {'name': ''},
      }, constraint);

      expect(violations.first.propertyPath, equals('user.name'));
    });
  });

  group('Constraint - CPF', () {
    test('should pass for valid CPF', () {
      final validator = Validator();
      expect(validator.isValid(CPFValidator.generate(), cpf), isTrue);
      expect(validator.isValid(CPFValidator.generate(true), cpf), isTrue);
    });

    test('should fail for invalid CPF', () {
      final validator = Validator();
      expect(validator.isValid('12345678901', cpf), isFalse);
      expect(validator.isValid('111.111.111-11', cpf), isFalse);
    });

    test('should skip null values', () {
      final validator = Validator();
      expect(validator.isValid(null, cpf), isTrue);
    });

    test('should skip non-string values', () {
      final validator = Validator();
      expect(validator.isValid(123, cpf), isTrue);
    });

    test('should skip empty strings', () {
      final validator = Validator();
      expect(validator.isValid('', cpf), isTrue);
    });
  });

  group('Constraint - CNPJ', () {
    test('should pass for valid CNPJ', () {
      final validator = Validator();
      expect(validator.isValid(CNPJValidator.generate(), cnpj), isTrue);
      expect(validator.isValid(CNPJValidator.generate(true), cnpj), isTrue);
    });

    test('should fail for invalid CNPJ', () {
      final validator = Validator();
      expect(validator.isValid('12345678901234', cnpj), isFalse);
    });

    test('should skip null and empty values', () {
      final validator = Validator();
      expect(validator.isValid(null, cnpj), isTrue);
      expect(validator.isValid('', cnpj), isTrue);
    });
  });

  group('Constraint - CpfOrCnpj', () {
    test('should pass for valid CPF', () {
      final validator = Validator();
      expect(validator.isValid(CPFValidator.generate(), cpfOrCnpj), isTrue);
    });

    test('should pass for valid CNPJ', () {
      final validator = Validator();
      expect(validator.isValid(CNPJValidator.generate(), cpfOrCnpj), isTrue);
    });

    test('should fail for invalid length', () {
      final validator = Validator();
      expect(validator.isValid('123456789', cpfOrCnpj), isFalse);
    });

    test('should fail for invalid CPF', () {
      final validator = Validator();
      expect(validator.isValid('12345678901', cpfOrCnpj), isFalse);
    });

    test('should fail for invalid CNPJ', () {
      final validator = Validator();
      expect(validator.isValid('12345678901234', cpfOrCnpj), isFalse);
    });
  });

  group('Constraint - BirthDate', () {
    test('should pass for valid birth date', () {
      final validator = Validator();
      final birthDate = DateTime(1990, 1, 1);
      expect(validator.isValid(birthDate, BirthDate()), isTrue);
    });

    test('should fail for future date', () {
      final validator = Validator();
      final futureDate = DateTime.now().add(Duration(days: 1));
      expect(validator.isValid(futureDate, BirthDate()), isFalse);
    });

    test('should fail if age below minimum', () {
      final validator = Validator();
      final tooYoung = DateTime.now().subtract(Duration(days: 365 * 10));
      final constraint = BirthDate(minAge: 18);
      expect(validator.isValid(tooYoung, constraint), isFalse);
    });

    test('should fail if age above maximum', () {
      final validator = Validator();
      final tooOld = DateTime.now().subtract(Duration(days: 365 * 150));
      final constraint = BirthDate(maxAge: 120);
      expect(validator.isValid(tooOld, constraint), isFalse);
    });

    test('should skip null values', () {
      final validator = Validator();
      expect(validator.isValid(null, BirthDate()), isTrue);
    });
  });

  group('Constraint - PastDate', () {
    test('should pass for past date', () {
      final validator = Validator();
      final yesterday = DateTime.now().subtract(Duration(days: 1));
      expect(validator.isValid(yesterday, pastDate), isTrue);
    });

    test('should pass for today when allowed', () {
      final validator = Validator();
      final today = DateTime.now();
      final constraint = PastDate(allowToday: true);
      expect(validator.isValid(today, constraint), isTrue);
    });

    test('should fail for today when not allowed', () {
      final validator = Validator();
      final today = DateTime.now();
      final constraint = PastDate(allowToday: false);
      expect(validator.isValid(today, constraint), isFalse);
    });

    test('should fail for future date', () {
      final validator = Validator();
      final tomorrow = DateTime.now().add(Duration(days: 1));
      expect(validator.isValid(tomorrow, pastDate), isFalse);
    });
  });

  group('Constraint - FutureDate', () {
    test('should pass for future date', () {
      final validator = Validator();
      final tomorrow = DateTime.now().add(Duration(days: 1));
      expect(validator.isValid(tomorrow, futureDate), isTrue);
    });

    test('should pass for today when allowed', () {
      final validator = Validator();
      final today = DateTime.now();
      final constraint = FutureDate(allowToday: true);
      expect(validator.isValid(today, constraint), isTrue);
    });

    test('should fail for today when not allowed', () {
      final validator = Validator();
      final today = DateTime.now();
      final constraint = FutureDate(allowToday: false);
      expect(validator.isValid(today, constraint), isFalse);
    });

    test('should fail for past date', () {
      final validator = Validator();
      final yesterday = DateTime.now().subtract(Duration(days: 1));
      expect(validator.isValid(yesterday, futureDate), isFalse);
    });
  });

  group('Constraint - DateRange', () {
    test('should pass for date within range', () {
      final validator = Validator();
      final min = DateTime(2020, 1, 1);
      final max = DateTime(2025, 12, 31);
      final constraint = DateRange(min: min, max: max);
      final testDate = DateTime(2023, 6, 15);

      expect(validator.isValid(testDate, constraint), isTrue);
    });

    test('should work with inclusive bounds', () {
      final validator = Validator();
      final min = DateTime(2020, 1, 1);
      final max = DateTime(2025, 12, 31);
      final constraint = DateRange(
        min: min,
        max: max,
        minInclusive: true,
        maxInclusive: true,
      );

      expect(validator.isValid(min, constraint), isTrue);
      expect(validator.isValid(max, constraint), isTrue);
    });

    test('should work with exclusive bounds', () {
      final validator = Validator();
      final min = DateTime(2020, 1, 1);
      final max = DateTime(2025, 12, 31);
      final constraint = DateRange(
        min: min,
        max: max,
        minInclusive: false,
        maxInclusive: false,
      );

      expect(validator.isValid(min, constraint), isFalse);
      expect(validator.isValid(max, constraint), isFalse);
    });

    test('should work with string dates', () {
      final validator = Validator();
      final min = DateTime(2020, 1, 1);
      final constraint = DateRange(min: min);

      expect(validator.isValid('2023-06-15', constraint), isTrue);
      expect(validator.isValid('2019-12-31', constraint), isFalse);
    });
  });

  group('Constraint - Comparison', () {
    test('GreaterThan should validate correctly', () {
      final validator = Validator();
      final constraint = GreaterThan(10);

      expect(validator.isValid(11, constraint), isTrue);
      expect(validator.isValid(10, constraint), isFalse);
      expect(validator.isValid(9, constraint), isFalse);
    });

    test('GreaterOrEqual should validate correctly', () {
      final validator = Validator();
      final constraint = GreaterOrEqual(10);

      expect(validator.isValid(11, constraint), isTrue);
      expect(validator.isValid(10, constraint), isTrue);
      expect(validator.isValid(9, constraint), isFalse);
    });

    test('LessThan should validate correctly', () {
      final validator = Validator();
      final constraint = LessThan(10);

      expect(validator.isValid(9, constraint), isTrue);
      expect(validator.isValid(10, constraint), isFalse);
      expect(validator.isValid(11, constraint), isFalse);
    });

    test('LessOrEqual should validate correctly', () {
      final validator = Validator();
      final constraint = LessOrEqual(10);

      expect(validator.isValid(9, constraint), isTrue);
      expect(validator.isValid(10, constraint), isTrue);
      expect(validator.isValid(11, constraint), isFalse);
    });
  });

  group('Constraint - MD5', () {
    test('should pass for valid MD5 hash', () {
      final validator = Validator();
      expect(
        validator.isValid('5d41402abc4b2a76b9719d911017c592', md5),
        isTrue,
      );
      expect(
        validator.isValid('098F6BCD4621D373CADE4E832627B4F6', md5),
        isTrue,
      );
    });

    test('should fail for invalid MD5 hash', () {
      final validator = Validator();
      expect(validator.isValid('invalid', md5), isFalse);
      expect(
        validator.isValid('5d41402abc4b2a76b9719d911017c59', md5),
        isFalse,
      ); // too short
      expect(
        validator.isValid('5d41402abc4b2a76b9719d911017c592z', md5),
        isFalse,
      ); // invalid char
    });

    test('should skip null values', () {
      final validator = Validator();
      expect(validator.isValid(null, md5), isTrue);
    });
  });

  group('Message Provider', () {
    test('should use default English messages', () {
      final validator = Validator();
      final violations = validator.validate(null, notNull);

      expect(violations.first.message, contains('should not be null'));
    });

    test('should use Portuguese messages', () {
      final validator = Validator(PortugueseValidationMessageProvider());
      final violations = validator.validate(null, notNull);

      expect(violations.first.message, contains('não deve ser nulo'));
    });

    test('should interpolate parameters', () {
      final validator = Validator();
      final constraint = Length(min: 5);
      final violations = validator.validate('ab', constraint);

      expect(violations.first.message, contains('5'));
    });

    test('custom message should override default', () {
      final validator = Validator();
      final constraint = NotNull(message: 'Este campo é obrigatório');
      final violations = validator.validate(null, constraint);

      expect(violations.first.message, equals('Este campo é obrigatório'));
    });
  });

  group('Complex Validation Scenarios', () {
    test('should validate nested objects', () {
      final validator = Validator();
      final constraint = Collection({
        'user': Collection({
          'name': notBlank,
          'email': All([notBlank, email]),
          'age': Range(min: 18, max: 120),
        }),
      });

      final validData = {
        'user': {
          'name': 'John Doe',
          'email': 'john@example.com',
          'age': 30,
        },
      };

      expect(validator.isValid(validData, constraint), isTrue);
    });

    test('should validate array of objects', () {
      final validator = Validator();
      final constraint = Collection({
        'users': Each(
          Collection({
            'name': notBlank,
            'email': email,
          }),
        ),
      });

      final validData = {
        'users': [
          {'name': 'John', 'email': 'john@example.com'},
          {'name': 'Jane', 'email': 'jane@example.com'},
        ],
      };

      expect(validator.isValid(validData, constraint), isTrue);
    });

    test('should collect multiple violations', () {
      final validator = Validator();
      final constraint = Collection({
        'name': All([notBlank, Length(min: 3)]),
        'email': All([notBlank, email]),
        'age': Range(min: 0, max: 120),
      });

      final invalidData = {
        'name': '',
        'email': 'invalid',
        'age': 150,
      };

      final violations = validator.validate(invalidData, constraint);
      expect(violations.length, greaterThan(2));
    });

    test('should validate with optional nested fields', () {
      final validator = Validator();
      final constraint = Collection({
        'name': notBlank,
        'address': Optional(
          Collection({
            'street': notBlank,
            'city': notBlank,
          }),
        ),
      });

      final dataWithoutAddress = {'name': 'John'};
      expect(validator.isValid(dataWithoutAddress, constraint), isTrue);

      final dataWithAddress = {
        'name': 'John',
        'address': {
          'street': 'Main St',
          'city': 'New York',
        },
      };
      expect(validator.isValid(dataWithAddress, constraint), isTrue);
    });

    test('should provide detailed violation paths', () {
      final validator = Validator();
      final constraint = Collection({
        'users': Each(
          Collection({
            'address': Collection({
              'city': notBlank,
            }),
          }),
        ),
      });

      final data = {
        'users': [
          {
            'address': {'city': 'NYC'},
          },
          {
            'address': {'city': null},
          },
        ],
      };

      final violations = validator.validate(data, constraint);
      expect(violations, hasLength(1));
      expect(violations.first.propertyPath, equals('users.[1].address.city'));
    });
  });

  group('Edge Cases', () {
    test('should handle empty collections', () {
      final validator = Validator();
      final constraint = Collection({});

      expect(validator.isValid({}, constraint), isTrue);
    });

    test('should handle deeply nested structures', () {
      final validator = Validator();
      final constraint = Collection({
        'a': Collection({
          'b': Collection({
            'c': Collection({
              'd': notBlank,
            }),
          }),
        }),
      });

      final data = {
        'a': {
          'b': {
            'c': {
              'd': 'value',
            },
          },
        },
      };

      expect(validator.isValid(data, constraint), isTrue);
    });

    test('should handle large lists efficiently', () {
      final validator = Validator();
      final constraint = Each(isString);
      final largeList = List.generate(1000, (i) => 'item_$i');

      expect(validator.isValid(largeList, constraint), isTrue);
    });

    test('should handle unicode strings', () {
      final validator = Validator();
      expect(validator.isValid('你好世界', notBlank), isTrue);
      expect(validator.isValid('🚀💻🎉', notBlank), isTrue);
    });

    test('should handle special characters in email', () {
      final validator = Validator();
      expect(validator.isValid('user+tag@example.com', email), isTrue);
      expect(validator.isValid('user.name@example.com', email), isTrue);
    });
  });
}

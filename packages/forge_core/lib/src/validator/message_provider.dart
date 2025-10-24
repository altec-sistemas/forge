/// Validation message keys as constants
class ValidationMessageKey {
  const ValidationMessageKey._();

  // Basic validations
  static const String notNull = 'not_null';
  static const String notBlank = 'not_blank';
  static const String invalidEmail = 'invalid_email';
  static const String invalidValue = 'invalid_value';
  static const String fieldRequired = 'field_required';
  static const String fieldNotAllowed = 'field_not_allowed';

  // Type validations
  static const String mustBeMap = 'must_be_map';
  static const String mustBeList = 'must_be_list';
  static const String mustBeString = 'must_be_string';
  static const String mustBeNum = 'must_be_num';
  static const String mustBeInt = 'must_be_int';
  static const String mustBeDouble = 'must_be_double';
  static const String mustBeBool = 'must_be_bool';

  // String validations
  static const String minLength = 'min_length';
  static const String maxLength = 'max_length';
  static const String invalidFormat = 'invalid_format';

  // Numeric validations
  static const String minValue = 'min_value';
  static const String maxValue = 'max_value';
  static const String greaterThan = 'greater_than';
  static const String greaterOrEqual = 'greater_or_equal';
  static const String lessThan = 'less_than';
  static const String lessOrEqual = 'less_or_equal';

  // Choice validation
  static const String invalidChoice = 'invalid_choice';

  // CPF validations
  static const String cpfOnlyDigits = 'cpf_only_digits';
  static const String cpfLength = 'cpf_length';
  static const String cpfInvalid = 'cpf_invalid';

  // CNPJ validations
  static const String cnpjOnlyDigits = 'cnpj_only_digits';
  static const String cnpjLength = 'cnpj_length';
  static const String cnpjInvalid = 'cnpj_invalid';

  // CPF or CNPJ validations
  static const String cpfOrCnpjOnlyDigits = 'cpf_or_cnpj_only_digits';
  static const String cpfOrCnpjInvalid = 'cpf_or_cnpj_invalid';
  static const String cpfOrCnpjInvalidLength = 'cpf_or_cnpj_invalid_length';

  // Phone validations
  static const String phoneInvalid = 'phone_invalid';

  // Birth date validations
  static const String birthDateFuture = 'birth_date_future';
  static const String birthDateMinAge = 'birth_date_min_age';
  static const String birthDateMaxAge = 'birth_date_max_age';

  // Date validations
  static const String pastDate = 'past_date';
  static const String pastDateOrToday = 'past_date_or_today';
  static const String futureDate = 'future_date';
  static const String futureDateOrToday = 'future_date_or_today';
  static const String dateRangeMinInclusive = 'date_range_min_inclusive';
  static const String dateRangeMinExclusive = 'date_range_min_exclusive';
  static const String dateRangeMaxInclusive = 'date_range_max_inclusive';
  static const String dateRangeMaxExclusive = 'date_range_max_exclusive';

  // MD5 validations
  static const String md5Invalid = 'md5_invalid';
  static const String md5NotMatch = 'md5_not_match';
}

/// Localized message provider
abstract class ValidationMessageProvider {
  final Map<String, String> messages;

  const ValidationMessageProvider(this.messages);

  /// Gets a message by key
  String getMessage(String key, [Map<String, dynamic>? params]) {
    var message = messages[key] ?? key;

    if (params != null) {
      params.forEach((key, value) {
        message = message.replaceAll('{$key}', value.toString());
      });
    }

    return message;
  }
}

/// Default provider in English
class DefaultValidationMessageProvider extends ValidationMessageProvider {
  const DefaultValidationMessageProvider()
    : super(const {
        // Basic validations
        ValidationMessageKey.notNull: 'This value should not be null.',
        ValidationMessageKey.notBlank: 'This value should not be blank.',
        ValidationMessageKey.invalidEmail:
            'This value is not a valid email address.',
        ValidationMessageKey.invalidValue: 'This value is not valid.',
        ValidationMessageKey.fieldRequired: 'This field is missing.',
        ValidationMessageKey.fieldNotAllowed: 'This field was not expected.',

        // Type validations
        ValidationMessageKey.mustBeMap: 'This value should be a key-value map.',
        ValidationMessageKey.mustBeList: 'This value should be a list.',
        ValidationMessageKey.mustBeString: 'This value should be a string.',
        ValidationMessageKey.mustBeNum: 'This value should be a number.',
        ValidationMessageKey.mustBeInt: 'This value should be an integer.',
        ValidationMessageKey.mustBeDouble: 'This value should be a double.',
        ValidationMessageKey.mustBeBool: 'This value should be a boolean.',

        // String validations
        ValidationMessageKey.minLength:
            'This value is too short. It should have {min} characters or more.',
        ValidationMessageKey.maxLength:
            'This value is too long. It should have {max} characters or less.',
        ValidationMessageKey.invalidFormat:
            'This value does not match the expected format.',

        // Numeric validations
        ValidationMessageKey.minValue: 'This value should be {min} or more.',
        ValidationMessageKey.maxValue: 'This value should be {max} or less.',
        ValidationMessageKey.greaterThan:
            'This value must be greater than {min}.',
        ValidationMessageKey.greaterOrEqual:
            'This value must be greater than or equal to {min}.',
        ValidationMessageKey.lessThan: 'This value must be less than {max}.',
        ValidationMessageKey.lessOrEqual:
            'This value must be less than or equal to {max}.',

        // Choice validation
        ValidationMessageKey.invalidChoice:
            'The value you selected is not a valid choice. Valid options: {choices}',

        // CPF validations
        ValidationMessageKey.cpfOnlyDigits: 'CPF must contain only digits.',
        ValidationMessageKey.cpfLength: 'CPF must have 11 digits.',
        ValidationMessageKey.cpfInvalid: 'Invalid CPF.',

        // CNPJ validations
        ValidationMessageKey.cnpjOnlyDigits: 'CNPJ must contain only digits.',
        ValidationMessageKey.cnpjLength: 'CNPJ must have 14 digits.',
        ValidationMessageKey.cnpjInvalid: 'Invalid CNPJ.',

        // CPF or CNPJ validations
        ValidationMessageKey.cpfOrCnpjOnlyDigits:
            'CPF or CNPJ must contain only digits.',
        ValidationMessageKey.cpfOrCnpjInvalidLength:
            'CPF must have 11 digits or CNPJ must have 14 digits.',
        ValidationMessageKey.cpfOrCnpjInvalid: 'Invalid CPF or CNPJ.',

        // Phone validations
        ValidationMessageKey.phoneInvalid: 'This is not a valid phone number.',

        // Birth date validations
        ValidationMessageKey.birthDateFuture:
            'Birth date cannot be in the future.',
        ValidationMessageKey.birthDateMinAge:
            'Minimum age must be {minAge} years.',
        ValidationMessageKey.birthDateMaxAge:
            'Maximum age must be {maxAge} years.',

        // Date validations
        ValidationMessageKey.pastDate: 'This date must be before today.',
        ValidationMessageKey.pastDateOrToday:
            'This date must be before or equal to today.',
        ValidationMessageKey.futureDate: 'This date must be after today.',
        ValidationMessageKey.futureDateOrToday:
            'This date must be after or equal to today.',
        ValidationMessageKey.dateRangeMinInclusive:
            'This date must be after or equal to {min}.',
        ValidationMessageKey.dateRangeMinExclusive:
            'This date must be after {min}.',
        ValidationMessageKey.dateRangeMaxInclusive:
            'This date must be before or equal to {max}.',
        ValidationMessageKey.dateRangeMaxExclusive:
            'This date must be before {max}.',

        // MD5 validations
        ValidationMessageKey.md5Invalid: 'This value must be a valid MD5 hash.',
        ValidationMessageKey.md5NotMatch:
            'The MD5 hash does not match the expected value.',
      });
}

/// Portuguese message provider
class PortugueseValidationMessageProvider extends ValidationMessageProvider {
  const PortugueseValidationMessageProvider()
    : super(const {
        // Basic validations
        ValidationMessageKey.notNull: 'Este valor não deve ser nulo.',
        ValidationMessageKey.notBlank: 'Este valor não deve ser vazio.',
        ValidationMessageKey.invalidEmail:
            'Este valor não é um endereço de e-mail válido.',
        ValidationMessageKey.invalidValue: 'Este valor não é válido.',
        ValidationMessageKey.fieldRequired: 'Este campo está ausente.',
        ValidationMessageKey.fieldNotAllowed: 'Este campo não era esperado.',

        // Type validations
        ValidationMessageKey.mustBeMap:
            'Este valor deve ser um mapa de chave-valor.',
        ValidationMessageKey.mustBeList: 'Este valor deve ser uma lista.',
        ValidationMessageKey.mustBeString: 'Este valor deve ser uma string.',
        ValidationMessageKey.mustBeNum: 'Este valor deve ser um número.',
        ValidationMessageKey.mustBeInt: 'Este valor deve ser um inteiro.',
        ValidationMessageKey.mustBeDouble: 'Este valor deve ser um double.',
        ValidationMessageKey.mustBeBool: 'Este valor deve ser um booleano.',

        // String validations
        ValidationMessageKey.minLength:
            'Este valor é muito curto. Deve ter {min} caracteres ou mais.',
        ValidationMessageKey.maxLength:
            'Este valor é muito longo. Deve ter {max} caracteres ou menos.',
        ValidationMessageKey.invalidFormat:
            'Este valor não corresponde ao formato esperado.',

        // Numeric validations
        ValidationMessageKey.minValue: 'Este valor deve ser {min} ou mais.',
        ValidationMessageKey.maxValue: 'Este valor deve ser {max} ou menos.',
        ValidationMessageKey.greaterThan:
            'Este valor deve ser maior que {min}.',
        ValidationMessageKey.greaterOrEqual:
            'Este valor deve ser maior ou igual a {min}.',
        ValidationMessageKey.lessThan: 'Este valor deve ser menor que {max}.',
        ValidationMessageKey.lessOrEqual:
            'Este valor deve ser menor ou igual a {max}.',

        // Choice validation
        ValidationMessageKey.invalidChoice:
            'O valor selecionado não é uma opção válida. Opções válidas: {choices}',

        // CPF validations
        ValidationMessageKey.cpfOnlyDigits: 'CPF deve conter apenas dígitos.',
        ValidationMessageKey.cpfLength: 'CPF deve ter 11 dígitos.',
        ValidationMessageKey.cpfInvalid: 'CPF inválido.',

        // CNPJ validations
        ValidationMessageKey.cnpjOnlyDigits: 'CNPJ deve conter apenas dígitos.',
        ValidationMessageKey.cnpjLength: 'CNPJ deve ter 14 dígitos.',
        ValidationMessageKey.cnpjInvalid: 'CNPJ inválido.',

        // CPF or CNPJ validations
        ValidationMessageKey.cpfOrCnpjOnlyDigits:
            'CPF ou CNPJ deve conter apenas dígitos.',
        ValidationMessageKey.cpfOrCnpjInvalidLength:
            'CPF deve ter 11 dígitos ou CNPJ deve ter 14 dígitos.',
        ValidationMessageKey.cpfOrCnpjInvalid: 'CPF ou CNPJ inválido.',

        // Phone validations
        ValidationMessageKey.phoneInvalid:
            'Este não é um número de telefone válido.',

        // Birth date validations
        ValidationMessageKey.birthDateFuture:
            'Data de nascimento não pode ser no futuro.',
        ValidationMessageKey.birthDateMinAge:
            'Idade mínima deve ser {minAge} anos.',
        ValidationMessageKey.birthDateMaxAge:
            'Idade máxima deve ser {maxAge} anos.',

        // Date validations
        ValidationMessageKey.pastDate: 'Esta data deve ser anterior a hoje.',
        ValidationMessageKey.pastDateOrToday:
            'Esta data deve ser anterior ou igual a hoje.',
        ValidationMessageKey.futureDate: 'Esta data deve ser posterior a hoje.',
        ValidationMessageKey.futureDateOrToday:
            'Esta data deve ser posterior ou igual a hoje.',
        ValidationMessageKey.dateRangeMinInclusive:
            'Esta data deve ser posterior ou igual a {min}.',
        ValidationMessageKey.dateRangeMinExclusive:
            'Esta data deve ser posterior a {min}.',
        ValidationMessageKey.dateRangeMaxInclusive:
            'Esta data deve ser anterior ou igual a {max}.',
        ValidationMessageKey.dateRangeMaxExclusive:
            'Esta data deve ser anterior a {max}.',

        // MD5 validations
        ValidationMessageKey.md5Invalid:
            'Este valor deve ser um hash MD5 válido.',
        ValidationMessageKey.md5NotMatch:
            'O hash MD5 não corresponde ao esperado.',
      });
}

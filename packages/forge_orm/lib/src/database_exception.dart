/// Base exception for database errors
/// All database-related exceptions should extend this class
abstract class DatabaseException implements Exception {
  final String message;
  final String? query;
  final List<dynamic>? parameters;
  final Object? originalError;
  final StackTrace? stackTrace;

  DatabaseException({
    required this.message,
    this.query,
    this.parameters,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('$runtimeType: $message');

    if (query != null) {
      buffer.write('\n  Query: $query');
    }

    if (parameters != null && parameters!.isNotEmpty) {
      buffer.write('\n  Parameters: $parameters');
    }

    if (originalError != null) {
      buffer.write('\n  Original error: $originalError');
    }

    return buffer.toString();
  }

  /// Returns a user-friendly error message
  String get userMessage => message;
}

/// Exception thrown when a database constraint is violated
/// Includes unique, foreign key, primary key, check, and not null constraints
class ConstraintViolationException extends DatabaseException {
  final ConstraintType constraintType;
  final String? constraintName;
  final String? tableName;
  final String? columnName;

  ConstraintViolationException({
    required super.message,
    required this.constraintType,
    this.constraintName,
    this.tableName,
    this.columnName,
    super.query,
    super.parameters,
    super.originalError,
    super.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer(
      'ConstraintViolationException: ${constraintType.name}',
    );

    if (tableName != null) {
      buffer.write(' on table "$tableName"');
    }

    if (columnName != null) {
      buffer.write(' column "$columnName"');
    }

    buffer.write(' - $message');

    if (constraintName != null) {
      buffer.write('\n  Constraint: $constraintName');
    }

    if (query != null) {
      buffer.write('\n  Query: $query');
    }

    return buffer.toString();
  }

  @override
  String get userMessage {
    switch (constraintType) {
      case ConstraintType.unique:
        return 'This value already exists and must be unique';
      case ConstraintType.foreignKey:
        return 'Cannot perform this operation due to related data';
      case ConstraintType.notNull:
        return 'Required field cannot be empty';
      case ConstraintType.primaryKey:
        return 'Duplicate primary key value';
      case ConstraintType.check:
        return 'Value does not meet requirements';
      default:
        return 'Data constraint violation';
    }
  }
}

/// Types of database constraints
enum ConstraintType {
  unique,
  foreignKey,
  primaryKey,
  check,
  notNull,
  unknown,
}

/// Exception thrown when SQL syntax is invalid
class SqlSyntaxException extends DatabaseException {
  final int? position;

  SqlSyntaxException({
    required super.message,
    this.position,
    super.query,
    super.parameters,
    super.originalError,
    super.stackTrace,
  });

  @override
  String get userMessage => 'Invalid database query syntax';
}

/// Exception thrown when database connection fails
class ConnectionException extends DatabaseException {
  final String? host;
  final int? port;

  ConnectionException({
    required super.message,
    this.host,
    this.port,
    super.originalError,
    super.stackTrace,
  }) : super(query: null, parameters: null);

  @override
  String toString() {
    final buffer = StringBuffer('ConnectionException: $message');

    if (host != null) {
      buffer.write('\n  Host: $host');
    }

    if (port != null) {
      buffer.write('\n  Port: $port');
    }

    if (originalError != null) {
      buffer.write('\n  Original error: $originalError');
    }

    return buffer.toString();
  }

  @override
  String get userMessage => 'Unable to connect to database';
}

/// Exception thrown when a database operation times out
class TimeoutException extends DatabaseException {
  final Duration? timeout;

  TimeoutException({
    required super.message,
    this.timeout,
    super.query,
    super.parameters,
    super.originalError,
    super.stackTrace,
  });

  @override
  String toString() {
    final buffer = StringBuffer('TimeoutException: $message');

    if (timeout != null) {
      buffer.write('\n  Timeout: ${timeout!.inMilliseconds}ms');
    }

    if (query != null) {
      buffer.write('\n  Query: $query');
    }

    return buffer.toString();
  }

  @override
  String get userMessage => 'Operation took too long to complete';
}

/// Exception thrown when a transaction fails
class TransactionException extends DatabaseException {
  final TransactionState? state;

  TransactionException({
    required super.message,
    this.state,
    super.query,
    super.parameters,
    super.originalError,
    super.stackTrace,
  });

  @override
  String get userMessage => 'Transaction failed to complete';
}

/// Transaction state when exception occurred
enum TransactionState {
  begin,
  commit,
  rollback,
  unknown,
}

/// Exception thrown when a deadlock is detected
class DeadlockException extends DatabaseException {
  DeadlockException({
    required super.message,
    super.query,
    super.parameters,
    super.originalError,
    super.stackTrace,
  });

  @override
  String get userMessage => 'Operation conflicted with another transaction';
}

/// Generic exception for query execution failures
class QueryExecutionException extends DatabaseException {
  QueryExecutionException({
    required super.message,
    super.query,
    super.parameters,
    super.originalError,
    super.stackTrace,
  });

  @override
  String get userMessage => 'Failed to execute database operation';
}

/// Exception thrown when table or column doesn't exist
class ObjectNotFoundException extends DatabaseException {
  final String? objectName;
  final DatabaseObjectType? objectType;

  ObjectNotFoundException({
    required super.message,
    this.objectName,
    this.objectType,
    super.query,
    super.parameters,
    super.originalError,
    super.stackTrace,
  });

  @override
  String get userMessage => 'Database object not found';
}

/// Types of database objects
enum DatabaseObjectType {
  table,
  column,
  indexx,
  view,
  procedure,
  function,
  unknown,
}

/// Parser for SQLite exceptions
/// Converts native SQLite errors into typed exceptions
class SqliteExceptionParser {
  /// Parses a SQLite error and returns appropriate typed exception
  static DatabaseException parse(
    Object error,
    String? query,
    List<dynamic>? parameters, {
    StackTrace? stackTrace,
  }) {
    final errorMsg = error.toString().toLowerCase();

    // UNIQUE constraint violation
    if (errorMsg.contains('unique constraint failed')) {
      final match = RegExp(
        r'unique constraint failed: (\w+)\.(\w+)',
      ).firstMatch(errorMsg);

      return ConstraintViolationException(
        message: 'Unique constraint violation',
        constraintType: ConstraintType.unique,
        tableName: match?.group(1),
        columnName: match?.group(2),
        query: query,
        parameters: parameters,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // FOREIGN KEY constraint violation
    if (errorMsg.contains('foreign key constraint failed')) {
      return ConstraintViolationException(
        message: 'Foreign key constraint violation',
        constraintType: ConstraintType.foreignKey,
        query: query,
        parameters: parameters,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // NOT NULL constraint violation
    if (errorMsg.contains('not null constraint failed')) {
      final match = RegExp(
        r'not null constraint failed: (\w+)\.(\w+)',
      ).firstMatch(errorMsg);

      return ConstraintViolationException(
        message: 'Not null constraint violation',
        constraintType: ConstraintType.notNull,
        tableName: match?.group(1),
        columnName: match?.group(2),
        query: query,
        parameters: parameters,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // CHECK constraint violation
    if (errorMsg.contains('check constraint failed')) {
      return ConstraintViolationException(
        message: 'Check constraint violation',
        constraintType: ConstraintType.check,
        query: query,
        parameters: parameters,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // No such table
    if (errorMsg.contains('no such table')) {
      final match = RegExp(r'no such table: (\w+)').firstMatch(errorMsg);

      return ObjectNotFoundException(
        message: 'Table does not exist',
        objectName: match?.group(1),
        objectType: DatabaseObjectType.table,
        query: query,
        parameters: parameters,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // No such column
    if (errorMsg.contains('no such column')) {
      final match = RegExp(r'no such column: (\w+)').firstMatch(errorMsg);

      return ObjectNotFoundException(
        message: 'Column does not exist',
        objectName: match?.group(1),
        objectType: DatabaseObjectType.column,
        query: query,
        parameters: parameters,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Syntax error
    if (errorMsg.contains('syntax error') || errorMsg.contains('near')) {
      return SqlSyntaxException(
        message: 'SQL syntax error',
        query: query,
        parameters: parameters,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Database locked
    if (errorMsg.contains('database is locked')) {
      return TimeoutException(
        message: 'Database is locked',
        query: query,
        parameters: parameters,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Generic fallback
    return QueryExecutionException(
      message: 'Query execution failed: $error',
      query: query,
      parameters: parameters,
      originalError: error,
      stackTrace: stackTrace,
    );
  }
}

/// Parser for MySQL exceptions
/// Converts native MySQL errors into typed exceptions
class MySqlExceptionParser {
  /// Parses a MySQL error and returns appropriate typed exception
  static DatabaseException parse(
    Object error,
    String? query,
    List<dynamic>? parameters, {
    StackTrace? stackTrace,
  }) {
    final errorMsg = error.toString().toLowerCase();

    // Extract MySQL error code if present
    final errorCodeMatch = RegExp(r'\b(\d{4})\b').firstMatch(errorMsg);
    final errorCode = errorCodeMatch?.group(1);

    // UNIQUE constraint violation (error 1062)
    if (errorMsg.contains('duplicate entry') || errorCode == '1062') {
      final match = RegExp(
        r"duplicate entry '([^']+)' for key '([^']+)'",
        caseSensitive: false,
      ).firstMatch(errorMsg);

      return ConstraintViolationException(
        message: 'Duplicate entry violation',
        constraintType: ConstraintType.unique,
        constraintName: match?.group(2),
        query: query,
        parameters: parameters,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // FOREIGN KEY constraint violation (errors 1451, 1452)
    if (errorMsg.contains('foreign key constraint') ||
        errorCode == '1451' ||
        errorCode == '1452') {
      return ConstraintViolationException(
        message: 'Foreign key constraint violation',
        constraintType: ConstraintType.foreignKey,
        query: query,
        parameters: parameters,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // NOT NULL constraint violation (error 1048)
    if ((errorMsg.contains('column') && errorMsg.contains('cannot be null')) ||
        errorCode == '1048') {
      final match = RegExp(
        r"column '([^']+)' cannot be null",
        caseSensitive: false,
      ).firstMatch(errorMsg);

      return ConstraintViolationException(
        message: 'Column cannot be null',
        constraintType: ConstraintType.notNull,
        columnName: match?.group(1),
        query: query,
        parameters: parameters,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Table doesn't exist (error 1146)
    if (errorMsg.contains("table") && errorMsg.contains("doesn't exist") ||
        errorCode == '1146') {
      final match = RegExp(
        r"table '([^']+)' doesn't exist",
        caseSensitive: false,
      ).firstMatch(errorMsg);

      return ObjectNotFoundException(
        message: 'Table does not exist',
        objectName: match?.group(1),
        objectType: DatabaseObjectType.table,
        query: query,
        parameters: parameters,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Unknown column (error 1054)
    if (errorMsg.contains('unknown column') || errorCode == '1054') {
      final match = RegExp(
        r"unknown column '([^']+)'",
        caseSensitive: false,
      ).firstMatch(errorMsg);

      return ObjectNotFoundException(
        message: 'Column does not exist',
        objectName: match?.group(1),
        objectType: DatabaseObjectType.column,
        query: query,
        parameters: parameters,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Syntax error (error 1064)
    if (errorMsg.contains('syntax') || errorCode == '1064') {
      return SqlSyntaxException(
        message: 'SQL syntax error',
        query: query,
        parameters: parameters,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Deadlock detected (error 1213)
    if (errorMsg.contains('deadlock') || errorCode == '1213') {
      return DeadlockException(
        message: 'Deadlock detected',
        query: query,
        parameters: parameters,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Lock timeout (error 1205)
    if (errorMsg.contains('lock wait timeout') || errorCode == '1205') {
      return TimeoutException(
        message: 'Lock wait timeout exceeded',
        query: query,
        parameters: parameters,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Connection errors (errors 2002, 2003, 2006, 2013)
    if (errorMsg.contains('connection') ||
        errorCode == '2002' ||
        errorCode == '2003' ||
        errorCode == '2006' ||
        errorCode == '2013') {
      return ConnectionException(
        message: 'Connection error: $error',
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Access denied (error 1045)
    if (errorMsg.contains('access denied') || errorCode == '1045') {
      return ConnectionException(
        message: 'Access denied - invalid credentials',
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Generic fallback
    return QueryExecutionException(
      message: 'Query execution failed: $error',
      query: query,
      parameters: parameters,
      originalError: error,
      stackTrace: stackTrace,
    );
  }
}

class UserService {
  String _username;

  UserService(this._username);

  String getUsername() => _username;

  void setUsername(String value) {
    _username = value;
  }

  String getEmail() => '$_username@example.com';

  void updateUser(String username, [int age = 0]) {
    _username = username;
  }
}

class ProductService {
  String _name = 'Product';

  String getName() => _name;

  void setName(String value) {
    _name = value;
  }

  void updateProduct(String name) {
    _name = name;
  }
}

class OrderService {
  final String orderId;

  OrderService(this.orderId);
}

// Annotations for testing
class TestAnnotation {
  final String value;
  const TestAnnotation(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestAnnotation &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class RouteAnnotation {
  final String path;
  const RouteAnnotation(this.path);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RouteAnnotation &&
          runtimeType == other.runtimeType &&
          path == other.path;

  @override
  int get hashCode => path.hashCode;
}

class InjectAnnotation {
  const InjectAnnotation();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InjectAnnotation && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

class ValidateAnnotation {
  const ValidateAnnotation();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ValidateAnnotation && runtimeType == other.runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

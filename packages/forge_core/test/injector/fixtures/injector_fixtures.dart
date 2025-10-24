class ServiceA {
  final String id;

  ServiceA() : id = DateTime.now().microsecondsSinceEpoch.toString();
}

class ServiceB {
  final ServiceA serviceA;
  ServiceB(this.serviceA);
}

class ServiceC {
  int callCount = 0;
  void incrementCall() => callCount++;
}

class ServiceD {
  final ServiceA serviceA;
  final ServiceB serviceB;
  ServiceD(this.serviceA, this.serviceB);
}

class ServiceWithOptional {
  final ServiceA? optionalService;
  ServiceWithOptional([this.optionalService]);
}

class DisposableService {
  bool isDisposed = false;
  void dispose() => isDisposed = true;
}

class ConfigService {
  final Map<String, dynamic> config;
  ConfigService(this.config);
}

class TestAnnotation {
  final String value;
  const TestAnnotation(this.value);
}

class RouteAnnotation {
  final String path;
  final String method;
  const RouteAnnotation(this.path, this.method);
}

class InjectAnnotation {
  const InjectAnnotation();
}

class ScopedAnnotation {
  final String scope;
  const ScopedAnnotation(this.scope);
}

class PriorityAnnotation {
  final int priority;
  const PriorityAnnotation(this.priority);
}

abstract class Logger {
  void log(String message);
}

class ConsoleLogger implements Logger {
  @override
  void log(String message) => print(message);
}

class FileLogger implements Logger {
  @override
  void log(String message) {}
}

abstract class Animal {
  String makeSound();
}

abstract class Mammal extends Animal {
  bool get hasFur => true;
}

class Dog extends Mammal {
  @override
  String makeSound() => 'Woof';
}

class Cat extends Mammal {
  @override
  String makeSound() => 'Meow';
}

class Bird extends Animal with Flyable {
  @override
  String makeSound() => 'Tweet';
}

mixin Flyable {
  void fly() {}
}

class Plane with Flyable {}

abstract class Repository<T> {
  T? find(String id);
}

class StringRepository implements Repository<String> {
  @override
  String? find(String id) => null;
}

class IntRepository implements Repository<int> {
  @override
  int? find(String id) => null;
}

abstract class Shape {
  double calculateArea();
}

class Circle implements Shape {
  final double radius;
  Circle([this.radius = 1.0]);

  @override
  double calculateArea() => 3.14 * radius * radius;
}

class Rectangle implements Shape {
  final double width;
  final double height;
  Rectangle([this.width = 1.0, this.height = 1.0]);

  @override
  double calculateArea() => width * height;
}

import 'access_control.dart';

class Passport<T> {
  final T user;
  final AccessLevel level;

  Passport({required this.user, required this.level});
}

class AnonymousPassport extends Passport<void> {
  AnonymousPassport(AccessLevel level) : super(user: null, level: level);
}

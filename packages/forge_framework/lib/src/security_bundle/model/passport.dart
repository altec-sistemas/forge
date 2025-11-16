import 'access_control.dart';

class Passport<T> {
  final T user;
  final AccessLevel level;

  Passport({required this.user, required this.level});
}

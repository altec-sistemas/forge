import '../security.dart';

class Firewall {
  final String name;
  final String? pattern;
  final Authenticator authenticator;

  Firewall({required this.name, this.pattern, required this.authenticator});
}

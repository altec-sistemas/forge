import '../model/access_control.dart';
import '../model/firewall.dart';
import '../security.dart';

class AccessControlConfig {
  final String path;
  final AccessLevel level;

  AccessControlConfig({required this.path, required this.level});
}

class SecurityConfig {
  final List<Firewall> firewalls;
  final List<AccessControl>? accessControls;

  SecurityConfig({required this.firewalls, this.accessControls});
}

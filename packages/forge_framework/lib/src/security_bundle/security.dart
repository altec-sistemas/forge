import 'dart:async';

import '../../forge_framework.dart';

abstract class Authenticator {
  FutureOr<Passport?> authenticate(Request request);
}

class Security {
  final List<Firewall> firewalls;
  final List<AccessControl>? accessControls;

  Security({required this.firewalls, this.accessControls});

  Future<T> user<T>(Request request) async {
    final passport = request.context['passport'] as Passport?;

    if (passport == null) {
      throw HttpException.unauthorized('Acesso Negado!');
    }

    return passport.user as T;
  }

  Firewall? getFirewallForRequest(RequestContext context) {
    if (context.request.context.containsKey('firewall')) {
      return context.request.context['firewall'] as Firewall;
    }

    for (var firewall in firewalls) {
      if (firewall.pattern == null) {
        return firewall;
      }

      if (_matchPath(context.request.requestedUri.path, firewall.pattern!)) {
        context.change(context: {'firewall': firewall});
        return firewall;
      }
    }

    return null;
  }

  Future<Passport?> _getPassport(
    RequestContext context,
    Firewall firewall,
  ) async {
    if (context.request.context.containsKey('passport')) {
      return context.request.context['passport'] as Passport;
    }

    final passport = await firewall.authenticator.authenticate(context.request);

    context.change(context: {'passport': passport});

    return passport;
  }

  Future<void> authenticate(RequestContext context) async {
    final firewall = getFirewallForRequest(context);
    if (firewall == null) return;

    final passport = await _getPassport(context, firewall);

    if (accessControls == null || accessControls!.isEmpty) {
      throw HttpException.unauthorized('Acesso negado.');
    }

    final path = context.request.requestedUri.path;

    for (var accessControl in accessControls!) {
      if (_matchPath(path, accessControl.path)) {
        if (accessControl.level == AccessLevel.public) return;

        if (passport != null &&
            passport.level.priority >= accessControl.level.priority) {
          return;
        }

        break; // Encontrou, mas não tem permissão
      }
    }

    throw HttpException.unauthorized('Acesso negado.');
  }

  bool _matchPath(String requestPath, String rule) {
    // Escapa pontos e outros caracteres regex
    var pattern = RegExp.escape(rule);

    // Transforma o "*" em ".*"
    pattern = pattern.replaceAll(r'\*', '.*');

    // Se o padrão já tiver grupo (ex: (login|user)), mantém
    // Mas como usamos escape acima, precisamos reverter grupos manuais
    pattern = pattern
        .replaceAllMapped(RegExp(r'\\\((.*?)\\\)'), (m) {
          return '(${m[1]})';
        })
        .replaceAll(r'\|', '|');

    // Regex com âncora (início ^ e fim $)
    final regex = RegExp('^$pattern\$');

    return regex.hasMatch(requestPath);
  }
}

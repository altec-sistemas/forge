import 'dart:async';

import 'package:forge_core/forge_core.dart';

import 'config/security_config.dart';
import 'security.dart';
import 'subscriber/security_subscriber.dart';

export 'config/security_config.dart';
export 'model/access_control.dart';
export 'model/firewall.dart';
export 'model/passport.dart';
export 'security.dart';

class SecurityBundle implements Bundle {
  @override
  Future<void> boot(Injector i) async {}

  @override
  Future<void> build(InjectorBuilder builder, String env) async {
    builder.registerSingleton<SecuritySubscriber>(
      (injector) => SecuritySubscriber(
        injector<Security>(),
      ),
    );

    builder.registerSingleton<Security>(
      (injector) {
        final config = injector.tryGet<SecurityConfig>();

        if (config == null) {
          throw Exception(
            'SecurityConfig not found in the injector. Please register it before using SecurityBundle.',
          );
        }

        return Security(
          firewalls: config.firewalls,
          accessControls: config.accessControls,
        );
      },
    );
  }

  @override
  Future<void> buildMetadata(
    MetadataRegistryBuilder metaBuilder,
    String env,
  ) async {}
}

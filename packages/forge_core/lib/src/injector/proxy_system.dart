import '../../forge_core.dart';

typedef MethodInterceptor =
    dynamic Function()? Function(
      String methodName,
      List<dynamic> positionalArgs,
      Map<Symbol, dynamic> namedArgs,
    );
typedef GetterInterceptor = dynamic Function()? Function(String getterName);
typedef SetterInterceptor =
    void Function()? Function(String setterName, dynamic value);

/// Handler for proxy interceptors
class ProxyHandler {
  final MethodInterceptor? onMethodCall;
  final GetterInterceptor? onGetterAccess;
  final SetterInterceptor? onSetterAccess;

  const ProxyHandler({
    this.onMethodCall,
    this.onGetterAccess,
    this.onSetterAccess,
  });
}

/// Base class for all generated proxies
abstract class AbstractProxy {
  final Object target;
  ProxyHandler handler;
  final ClassMetadata metadata;

  AbstractProxy(this.target, this.handler, this.metadata);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final memberName = invocation.memberName.toString();
    // Extract clean name from Symbol
    final name = memberName.substring(8, memberName.length - 2);

    if (invocation.isGetter) {
      // Call interceptor first
      if (handler.onGetterAccess != null) {
        final callback = handler.onGetterAccess!(name);
        if (callback != null) {
          return callback();
        }
      }

      // Not intercepted, use metadata to get actual value
      final getter = metadata.getters?.firstWhere(
        (g) => g.name == name,
        orElse: () => throw UnsupportedError(
          'Getter $name not found in metadata for ${metadata.typeMetadata.type}',
        ),
      );
      return getter!.getValue(target);
    }

    if (invocation.isSetter) {
      final cleanName = name.replaceAll('=', '');
      final value = invocation.positionalArguments.first;

      // Call interceptor first
      if (handler.onSetterAccess != null) {
        final callback = handler.onSetterAccess!(cleanName, value);
        if (callback != null) {
          callback();
          return null;
        }
      }

      // Not intercepted, use metadata to set actual value
      final setter = metadata.setters?.firstWhere(
        (s) => s.name == cleanName,
        orElse: () => throw UnsupportedError(
          'Setter $cleanName not found in metadata for ${metadata.typeMetadata.type}',
        ),
      );
      setter!.setValue(target, value);
      return null;
    }

    if (invocation.isMethod) {
      // Call interceptor first
      if (handler.onMethodCall != null) {
        final callback = handler.onMethodCall!(
          name,
          invocation.positionalArguments,
          invocation.namedArguments,
        );
        if (callback != null) {
          return callback();
        }
      }

      // Not intercepted, use metadata to invoke actual method
      final method = metadata.methods?.firstWhere(
        (m) => m.name == name,
        orElse: () => throw UnsupportedError(
          'Method $name not found in metadata for ${metadata.typeMetadata.type}',
        ),
      );

      final func = method!.getMethod(target);
      return Function.apply(
        func,
        invocation.positionalArguments,
        invocation.namedArguments,
      );
    }

    return super.noSuchMethod(invocation);
  }

  @override
  bool operator ==(Object other) {
    if (other is AbstractProxy) {
      return other.target == target;
    }

    return false;
  }

  @override
  int get hashCode => target.hashCode;
}

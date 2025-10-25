mixin GenericCaller<T> {
  R captureGeneric<R>(R Function<U>() fn) {
    return fn<T>();
  }
}

bool isSameType<C, T>() {
  return <C>[] is List<T>;
}

bool isValueSubtypeOf<C, T>(C value) {
  return <C>[] is List<T>;
}

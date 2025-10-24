mixin GenericCaller<T> {
  R captureGeneric<R>(R Function<U>() fn) {
    return fn<T>();
  }
}

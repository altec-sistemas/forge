class Validator {
  const Validator();
}

class NotBlank {
  const NotBlank();
}

class OnEvent<T> {
  const OnEvent();
}

class CollectionTransformer<T> {
  final List<Transformers> transformer;
  const CollectionTransformer(this.transformer);
}

class Transformers<T> {
  const Transformers();
}

class OtherAnnotation {
  final Map<String, CollectionTransformer> params;
  final OnEvent onEvent;
  final Map<String, Map<String, OtherAnnotation>>? nested;
  const OtherAnnotation(
    this.params, {
    required this.onEvent,
    required this.nested,
  });
}

import '../forge_core.dart';

class CoreBundle extends Bundle {
  @override
  Future<void> build(InjectorBuilder builder, String env) async {
    builder.registerFactory<Transformer>(
      (i) => MapTransformer(),
      name: 'serializer.transformer.map',
    );
    builder.registerFactory<Transformer>(
      (i) => ListTransformer(),
      name: 'serializer.transformer.list',
    );
    builder.registerFactory<Transformer>(
      (i) => PrimitiveTransformer(),
      name: 'serializer.transformer.primitive',
    );
    builder.registerFactory<Transformer>(
      (i) => MetadataTransformer(i()),
      name: 'serializer.transformer.enum',
    );
    builder.registerFactory<Encoder>(
      (i) => JsonEncoder(),
      name: 'serializer.encoder.json',
    );

    builder.registerFactory<Serializer>(
      (i) => Serializer(
        transformers: i.all<Transformer>(),
        encoders: i.all<Encoder>(),
      ),
    );

    builder.registerFactory<Validator>(
      (i) => Validator(
        i.contains<ValidationMessageProvider>()
            ? i.get<ValidationMessageProvider>()
            : null,
      ),
    );

    builder.registerFactory<ConstraintExtractor>(
      (i) => ConstraintExtractor(i.get<MetadataRegistry>()),
    );
  }

  @override
  Future<void> boot(Injector i) async {}
}

enum AccessLevel {
  public(0),
  protected(1),
  private(2);

  final int priority;

  const AccessLevel(this.priority);
}

class AccessControl {
  final String path;
  final AccessLevel level;

  AccessControl({required this.path, required this.level});
}

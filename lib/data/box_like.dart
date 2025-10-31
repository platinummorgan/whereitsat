abstract class BoxLike<T> {
  T? get(String id);
  Iterable<T> get values;
  Future<void> put(String id, T value);
  Future<void> delete(String id);
}

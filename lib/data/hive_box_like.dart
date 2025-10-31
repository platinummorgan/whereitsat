import 'package:hive/hive.dart';
import 'box_like.dart';

class HiveBoxLike<T> implements BoxLike<T> {
  final Box<T> box;
  HiveBoxLike(this.box);

  @override
  T? get(String id) => box.get(id);

  @override
  Iterable<T> get values => box.values;

  @override
  Future<void> put(String id, T value) => box.put(id, value);

  @override
  Future<void> delete(String id) => box.delete(id);
}

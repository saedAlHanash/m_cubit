/// Standardized Result / Pair representation for API & Cache responses.
class CachePair<T, E> {
  final T? first;
  final E? second;

  const CachePair(this.first, this.second);

  bool get isSuccess => first != null;
  bool get isError => second != null;

  @override
  String toString() => 'CachePair(first: $first, second: $second)';
}

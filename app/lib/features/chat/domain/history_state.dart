import 'package:flutter/foundation.dart';

@immutable
class HistoryState {
  const HistoryState({
    this.loading = false,
    this.reachedStart = false,
    this.failed = false,
  });

  final bool loading;
  final bool reachedStart;
  final bool failed;

  @override
  bool operator ==(Object other) =>
      other is HistoryState &&
      other.loading == loading &&
      other.reachedStart == reachedStart &&
      other.failed == failed;

  @override
  int get hashCode => Object.hash(loading, reachedStart, failed);
}

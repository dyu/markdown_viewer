import 'dart:async' show Completer, Future, FutureOr;

typedef Task<T> = T Function();

class DedupAsync<T> {
  final _completer = Completer<T>();

  DedupAsync(
    Task<FutureOr<T>> task,
    String dedupKey,
    Map<String, DedupAsync<T>?> dedupMap, {
    Map<String, T>? resultMap,
  }) {
    dedupMap[dedupKey] = this;
    void resolve(T data) {
      dedupMap[dedupKey] = null;
      if (resultMap != null && data != null) {
        resultMap[dedupKey] = data;
      }
      _completer.complete(data);
    };
    void reject(Object error, [StackTrace? stackTrace]) {
      dedupMap[dedupKey] = null;

      _completer.completeError(error, stackTrace);
    };
    try {
      final ret = task();
      if (ret is Future<T>) {
        ret.then(resolve).catchError(reject);
      } else {
        resolve(ret);
      }
    } catch (error, stackTrace) {
      reject(error, stackTrace);
    }
  }

  Future<T> get future => _completer.future;
}

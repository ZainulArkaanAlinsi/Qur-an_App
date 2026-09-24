import 'dart:async';

/// Semua sumber sudah dicoba dan tidak ada yang berhasil.
class SourceUnavailable implements Exception {
  const SourceUnavailable(this.errors);

  /// Galat tiap percobaan, urut sesuai sumbernya.
  final List<Object> errors;

  @override
  String toString() => 'Semua sumber gagal: ${errors.join(' | ')}';
}

/// Hasil dari sumber yang berhasil, beserta urutannya (0 = sumber utama).
class SourceResult<T> {
  const SourceResult(this.value, this.index);

  final T value;
  final int index;

  bool get fromFallback => index > 0;
}

/// Mencoba [attempts] satu per satu. Sumber berikutnya dipakai kalau sumber
/// sebelumnya melempar galat atau melewati [timeout].
Future<SourceResult<T>> firstAvailable<T>(
  List<Future<T> Function()> attempts, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final errors = <Object>[];
  for (var i = 0; i < attempts.length; i++) {
    try {
      final value = await attempts[i]().timeout(timeout);
      return SourceResult(value, i);
    } on Object catch (error) {
      errors.add(error);
    }
  }
  throw SourceUnavailable(errors);
}

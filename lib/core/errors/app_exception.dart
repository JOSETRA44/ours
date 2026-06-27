abstract class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

class GeneralException extends AppException {
  const GeneralException(super.message);
}

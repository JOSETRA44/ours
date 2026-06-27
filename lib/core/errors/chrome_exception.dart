import 'app_exception.dart';

class ChromeNotFoundException extends AppException {
  const ChromeNotFoundException()
      : super(
            'Chrome executable not found. Please set the path in Settings.');
}

class ChromeNotDebuggableException extends AppException {
  const ChromeNotDebuggableException()
      : super(
            'Chrome is running without remote debugging enabled. '
            'Please close Chrome and activate the workspace again.');
}

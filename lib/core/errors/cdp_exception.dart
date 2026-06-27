import 'app_exception.dart';

class CdpException extends AppException {
  const CdpException(super.message);
}

class CdpTimeoutException extends CdpException {
  const CdpTimeoutException(super.message);
}

class CdpConnectionException extends CdpException {
  const CdpConnectionException(super.message);
}

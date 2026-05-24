class RhwpException implements Exception {
  const RhwpException(this.message);

  final String message;

  @override
  String toString() => 'RhwpException: $message';
}

class RhwpClosedException extends RhwpException {
  const RhwpClosedException() : super('The rhwp document is already closed.');
}

class RhwpUnsupportedPlatformException extends RhwpException {
  const RhwpUnsupportedPlatformException(super.message);
}

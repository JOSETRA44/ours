class CdpEvent {
  final String method;
  final Map<String, dynamic> params;

  const CdpEvent({required this.method, required this.params});
}

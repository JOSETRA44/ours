class CdpTab {
  final String targetId;
  final String url;
  final String title;

  const CdpTab({
    required this.targetId,
    required this.url,
    required this.title,
  });

  bool get isNavigable =>
      url.startsWith('http://') || url.startsWith('https://');

  @override
  String toString() => 'CdpTab(id=$targetId, url=$url)';
}

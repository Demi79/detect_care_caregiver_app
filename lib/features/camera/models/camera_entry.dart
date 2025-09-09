class CameraEntry {
  final String id;
  final String name;
  final String url;
  final String? thumb;
  final bool isOnline;

  const CameraEntry({
    required this.id,
    required this.name,
    required this.url,
    this.thumb,
    this.isOnline = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'thumb': thumb,
    'isOnline': isOnline,
  };

  factory CameraEntry.fromJson(Map<String, dynamic> j) => CameraEntry(
    id: j['camera_id']?.toString() ?? '',
    name: j['camera_name']?.toString() ?? 'Camera',
    url:
        j['url']?.toString() ??
        '', // Nếu API có url, giữ nguyên, nếu không có thì để rỗng
    thumb: j['thumb']?.toString(),
    isOnline: j['isOnline'] is bool
        ? j['isOnline']
        : (j['isOnline']?.toString() == 'true'),
  );
}

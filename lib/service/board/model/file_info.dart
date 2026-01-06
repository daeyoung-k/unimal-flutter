class FileInfo {
  final String fileId;
  final String fileUrl;

  FileInfo({
    required this.fileId,
    required this.fileUrl,
  });

  factory FileInfo.fromJson(Map<String, dynamic> json) {
    return FileInfo(
      fileId: json['fileId'] as String? ?? '',
      fileUrl: json['fileUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fileId': fileId,
      'fileUrl': fileUrl,
    };
  }
}
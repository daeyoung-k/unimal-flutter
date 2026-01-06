import 'package:http_parser/http_parser.dart';

enum ImageMimeType {
  jpeg('jpg', 'jpeg', 'image/jpeg'),
  png('png', 'image/png'),
  gif('gif', 'image/gif'),
  webp('webp', 'image/webp'),
  bmp('bmp', 'image/bmp'),
  heic('heic', 'image/heic'),
  heif('heif', 'image/heif');

  const ImageMimeType(this.extension, this.mimeType, [String? altExtension])
      : altExtension = altExtension;

  final String extension;
  final String? altExtension;
  final String mimeType;

  // 확장자로부터 MIME 타입 찾기
  static ImageMimeType? fromExtension(String extension) {
    final lowerExt = extension.toLowerCase();
    
    for (final type in ImageMimeType.values) {
      if (type.extension == lowerExt || type.altExtension == lowerExt) {
        return type;
      }
    }
    return null;
  }

  // MediaType 객체로 변환
  MediaType toMediaType() {
    return MediaType('image', extension);
  }

  // 기본 MIME 타입 (jpeg)
  static ImageMimeType get defaultType => ImageMimeType.jpeg;
}

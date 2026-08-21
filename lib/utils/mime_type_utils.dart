import 'package:http_parser/http_parser.dart';

/// 파일 확장자 → 업로드용 MIME 타입.
///
/// 서버(photo 모듈)는 이 값을 그대로 S3 오브젝트의 Content-Type 으로 저장하고,
/// CloudFront 가 그 헤더로 서빙한다. 그래서 여기서 비표준 타입을 보내면 앱이
/// 아니라 **공유 링크 미리보기(og:image) 를 읽는 외부 크롤러 쪽에서** 탈이 난다.
enum ImageMimeType {
  // 인자 순서: (확장자, MIME 타입, [대체 확장자])
  jpeg('jpg', 'image/jpeg', 'jpeg'),
  png('png', 'image/png'),
  gif('gif', 'image/gif'),
  webp('webp', 'image/webp'),
  bmp('bmp', 'image/bmp'),
  heic('heic', 'image/heic'),
  heif('heif', 'image/heif');

  const ImageMimeType(this.extension, this.mimeType, [this.altExtension]);

  /// 대표 확장자 (소문자).
  final String extension;

  /// 같은 타입을 가리키는 다른 확장자. 없으면 null. (jpg ↔ jpeg)
  final String? altExtension;

  /// 표준 MIME 타입 문자열.
  final String mimeType;

  /// 확장자로 타입을 찾는다. 대소문자 무시. 모르는 확장자면 null.
  static ImageMimeType? fromExtension(String extension) {
    final lowerExt = extension.toLowerCase();

    for (final type in ImageMimeType.values) {
      if (type.extension == lowerExt || type.altExtension == lowerExt) {
        return type;
      }
    }
    return null;
  }

  /// http 패키지의 MultipartFile 에 넘길 Content-Type.
  ///
  /// 예전엔 `MediaType('image', extension)` 이었다. 확장자와 MIME 서브타입이
  /// 같다고 가정한 건데 JPEG 만 다르다(확장자 jpg, 서브타입 jpeg). 그래서
  /// 사진 대부분이 비표준인 `image/jpg` 로 올라가고 있었다.
  /// 이제는 선언된 [mimeType] 을 그대로 쓴다.
  MediaType toMediaType() => MediaType.parse(mimeType);

  /// 확장자를 못 알아봤을 때의 기본값.
  static ImageMimeType get defaultType => ImageMimeType.jpeg;
}

/// 표시용 타이틀 헬퍼.
///
/// 타이틀이 비어 있으면 본문 첫 줄 앞 15자를 유도 타이틀로 사용한다.
/// 유도 타이틀은 표시 시점에만 계산 — DB에 저장하지 않는다.
/// (docs/share-card-redesign.md §5)
String displayTitle(String title, String content) {
  final trimmedTitle = title.trim();
  if (trimmedTitle.isNotEmpty) return trimmedTitle;

  final firstLine = content.trim().split('\n').first.trim();
  return firstLine.length > 15 ? firstLine.substring(0, 15) : firstLine;
}

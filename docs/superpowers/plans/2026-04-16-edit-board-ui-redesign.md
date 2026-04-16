# Edit Board UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `edit_board.dart`(수정하기) 화면을 `add_item.dart`(공유하기)와 동일한 그라디언트+카드 스타일로 리디자인

**Architecture:** 단일 파일(`edit_board.dart`) 수정. 그라디언트 배경 + 흰색 카드 레이아웃 + 5단계 슬라이드/페이드 입장 애니메이션을 add_item.dart 패턴 그대로 적용. 커스텀 헤더에 뒤로가기(←) + "수정하기" 타이틀 + 삭제(🗑) 버튼 배치.

**Tech Stack:** Flutter, Dart, GetX, Pretendard

---

## Files

| 동작 | 파일 |
|---|---|
| Modify | `lib/screens/board/edit_board/edit_board.dart` |

---

### Task 1: 색상 상수 + 애니메이션 필드 선언

**Files:**
- Modify: `lib/screens/board/edit_board/edit_board.dart`

- [ ] **Step 1: `_EditBoardScreenState`에 `SingleTickerProviderStateMixin` 추가**

```dart
class _EditBoardScreenState extends State<EditBoardScreen>
    with SingleTickerProviderStateMixin {
```

- [ ] **Step 2: State 클래스 상단 필드 선언부에 상수 + 애니메이션 필드 추가**

기존 `final BoardApiService _boardApiService = ...` 위에 삽입:

```dart
static const Color _primary = Color(0xFF7AB3FF);
static const Color _primaryDark = Color(0xFF3578E5);

late AnimationController _ctrl;
late Animation<Offset> _headerSlide;
late Animation<double> _headerFade;
late Animation<Offset> _card1Slide;
late Animation<double> _card1Fade;
late Animation<Offset> _card2Slide;
late Animation<double> _card2Fade;
late Animation<Offset> _card3Slide;
late Animation<double> _card3Fade;
late Animation<double> _btnFade;
```

---

### Task 2: initState() + dispose() 업데이트

**Files:**
- Modify: `lib/screens/board/edit_board/edit_board.dart:33-46`

- [ ] **Step 1: initState()를 아래로 전체 교체**

```dart
@override
void initState() {
  super.initState();
  _boardPost = Get.arguments as BoardPost;
  _titleController.text = _boardPost.title;
  _contentController.text = _boardPost.content;
  _isShow = _boardPost.show == 'PUBLIC';

  _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );
  _headerSlide = Tween(begin: const Offset(0, -0.3), end: Offset.zero).animate(
    CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)),
  );
  _headerFade = Tween(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.35, curve: Curves.easeOut)),
  );
  _card1Slide = Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(
    CurvedAnimation(parent: _ctrl, curve: const Interval(0.15, 0.5, curve: Curves.easeOut)),
  );
  _card1Fade = Tween(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(parent: _ctrl, curve: const Interval(0.15, 0.45, curve: Curves.easeOut)),
  );
  _card2Slide = Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(
    CurvedAnimation(parent: _ctrl, curve: const Interval(0.3, 0.65, curve: Curves.easeOut)),
  );
  _card2Fade = Tween(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(parent: _ctrl, curve: const Interval(0.3, 0.6, curve: Curves.easeOut)),
  );
  _card3Slide = Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(
    CurvedAnimation(parent: _ctrl, curve: const Interval(0.45, 0.8, curve: Curves.easeOut)),
  );
  _card3Fade = Tween(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(parent: _ctrl, curve: const Interval(0.45, 0.75, curve: Curves.easeOut)),
  );
  _btnFade = Tween(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(parent: _ctrl, curve: const Interval(0.65, 1.0, curve: Curves.easeOut)),
  );
  _ctrl.forward();
}
```

- [ ] **Step 2: dispose()에 `_ctrl.dispose()` 추가**

```dart
@override
void dispose() {
  _ctrl.dispose();
  _titleController.dispose();
  _contentController.dispose();
  super.dispose();
}
```

---

### Task 3: build() — 그라디언트 Scaffold + 커스텀 헤더

**Files:**
- Modify: `lib/screens/board/edit_board/edit_board.dart`

- [ ] **Step 1: 기존 build() 전체를 아래로 교체 (카드 내용은 Task 4–6에서 채움)**

```dart
@override
Widget build(BuildContext context) {
  return GestureDetector(
    onTap: () => FocusScope.of(context).unfocus(),
    child: Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_primaryDark, _primary, Color(0xFFA8CCFF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 헤더
              FadeTransition(
                opacity: _headerFade,
                child: SlideTransition(
                  position: _headerSlide,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                          onPressed: () => Get.back(),
                        ),
                        const Expanded(
                          child: Text(
                            '수정하기',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
                          onPressed: _confirmDelete,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // 본문
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 카드들 (Task 4–6)
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
```

- [ ] **Step 2: `flutter analyze` 실행 — 에러 없음 확인**

```bash
flutter analyze lib/screens/board/edit_board/edit_board.dart
```

---

### Task 4: Card 1 — 이미지 섹션

**Files:**
- Modify: `lib/screens/board/edit_board/edit_board.dart`

- [ ] **Step 1: build()의 `// 카드들 (Task 4–6)` 위치를 아래로 교체**

```dart
// 이미지 섹션 (card1)
FadeTransition(
  opacity: _card1Fade,
  child: SlideTransition(
    position: _card1Slide,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '첫 번째 사진이 지도 위 스토리의 대표 이미지로 표시돼요.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontFamily: 'Pretendard',
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // 기존 이미지 (네트워크)
              ..._remainingFiles.map((file) => _buildExistingImageItem(file)),
              // 새로 추가한 이미지 (로컬 파일)
              ..._newImages.asMap().entries.map((e) => _buildNewImageItem(e.key, e.value)),
              // 추가 버튼 (최대 5장)
              if (_remainingFiles.length + _newImages.length < 5)
                GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add_rounded, color: _primary, size: 22),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_remainingFiles.length + _newImages.length}/5',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                            fontFamily: 'Pretendard',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    ),
  ),
),
// 제목 + 내용 + 토글 + 버튼 (Task 5–6)
```

- [ ] **Step 2: `_buildExistingImageItem` 메서드를 add_item 스타일로 교체**

```dart
Widget _buildExistingImageItem(FileInfo file) {
  return Padding(
    padding: const EdgeInsets.only(right: 10),
    child: Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.network(
            file.fileUrl,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 80,
              height: 80,
              color: Colors.white.withValues(alpha: 0.2),
              child: const Icon(Icons.broken_image, color: Colors.white),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removeExistingImage(file.fileId),
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Color(0xFFFF6B6B),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 13),
            ),
          ),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 3: `_buildNewImageItem` 메서드를 add_item 스타일로 교체**

```dart
Widget _buildNewImageItem(int index, File file) {
  return Padding(
    padding: const EdgeInsets.only(right: 10),
    child: Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.file(file, width: 80, height: 80, fit: BoxFit.cover),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removeNewImage(index),
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Color(0xFFFF6B6B),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 13),
            ),
          ),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 4: 기존 `_buildAddImageButton()` 메서드 삭제** (인라인으로 대체됨)

---

### Task 5: Card 2 — 제목 + 내용 카드

**Files:**
- Modify: `lib/screens/board/edit_board/edit_board.dart`

- [ ] **Step 1: `// 제목 + 내용 + 토글 + 버튼 (Task 5–6)` 위치를 아래로 교체**

```dart
// 제목 + 내용 카드 (card2)
FadeTransition(
  opacity: _card2Fade,
  child: SlideTransition(
    position: _card2Slide,
    child: Column(
      children: [
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '제목',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 16,
                  color: Color(0xFF1A1A2E),
                ),
                decoration: const InputDecoration(
                  hintText: '제목을 입력하세요.',
                  hintStyle: TextStyle(color: Colors.grey, fontFamily: 'Pretendard'),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '내용',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _contentController,
                onChanged: (_) => setState(() {}),
                maxLines: 5,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 15,
                  color: Color(0xFF1A1A2E),
                ),
                decoration: const InputDecoration(
                  hintText: '내용을 입력하세요.',
                  hintStyle: TextStyle(color: Colors.grey, fontFamily: 'Pretendard'),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    ),
  ),
),
// 토글 + 버튼 (Task 6)
```

---

### Task 6: Card 3 — 지도 노출 토글 + 저장 버튼

**Files:**
- Modify: `lib/screens/board/edit_board/edit_board.dart`

- [ ] **Step 1: `// 토글 + 버튼 (Task 6)` 위치를 아래로 교체**

```dart
// 지도 노출 토글 (card3)
FadeTransition(
  opacity: _card3Fade,
  child: SlideTransition(
    position: _card3Slide,
    child: _buildCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '지도 노출',
                  style: TextStyle(
                    color: Color(0xFF1A1A2E),
                    fontFamily: 'Pretendard',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  '켜두면 내 스토리가 지도에 핀으로 표시돼요.',
                  style: TextStyle(
                    color: Colors.grey,
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isShow,
            onChanged: (v) => setState(() => _isShow = v),
            activeColor: _primary,
          ),
        ],
      ),
    ),
  ),
),
const SizedBox(height: 20),

// 저장 버튼
FadeTransition(
  opacity: _btnFade,
  child: SizedBox(
    width: double.infinity,
    height: 56,
    child: ElevatedButton(
      onPressed: (_canSave() && !_isSaving) ? _savePost : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: _canSave() && !_isSaving
            ? Colors.white.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.4),
        foregroundColor: _primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: _canSave() && !_isSaving ? 6 : 0,
        shadowColor: Colors.black.withValues(alpha: 0.15),
      ),
      child: _isSaving
          ? const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(_primary),
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  '저장 중...',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _primary,
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: _canSave() ? _primary : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  '수정 완료',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _canSave() ? _primary : Colors.grey,
                  ),
                ),
              ],
            ),
    ),
  ),
),
```

---

### Task 7: _buildCard() 헬퍼 추가 + 정리 + 커밋

**Files:**
- Modify: `lib/screens/board/edit_board/edit_board.dart`

- [ ] **Step 1: dispose() 아래에 `_buildCard()` 헬퍼 추가**

```dart
Widget _buildCard({required Widget child}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: child,
  );
}
```

- [ ] **Step 2: flutter analyze 실행 — 에러 없음 확인**

```bash
flutter analyze lib/screens/board/edit_board/edit_board.dart
```

에러 없고 warn만 있어야 함 (기존 deprecated warn 제외).

- [ ] **Step 3: 커밋**

```bash
git add lib/screens/board/edit_board/edit_board.dart
git commit -m "feat: 수정하기 화면 UI 공유하기와 동일한 그라디언트 스타일로 개선"
```

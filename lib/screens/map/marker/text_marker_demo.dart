import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import 'package:unimal/screens/map/marker/text_marker_widgets.dart';

/// 텍스트 전용 커스텀 마커 데모 (프론트 전용 · 목 데이터).
///
/// 목적: 백엔드 없이 줌인/줌아웃 전환과 마커 렌더를 눈으로 확인.
/// - 줌 >= [_cardZoom] : [TextMarkerCard] (카드)
/// - 줌 <  [_cardZoom] : [TextMarkerDot]  (원 글리프 + 라벨)
///
/// 실제 적용 시엔 map_naver.dart 의 마커 빌드 루프에서 이 위젯들을 골라
/// `NOverlayImage.fromWidget` 으로 아이콘을 만들면 된다. (사진 글은 기존 방식 유지)
class TextMarkerDemoScreen extends StatefulWidget {
  const TextMarkerDemoScreen({super.key});

  @override
  State<TextMarkerDemoScreen> createState() => _TextMarkerDemoScreenState();
}

class _MockPost {
  const _MockPost({
    required this.id,
    required this.position,
    this.title,
    required this.body,
  });

  final String id;
  final NLatLng position;
  final String? title;
  final String body;

  /// 줌아웃 라벨: 제목 없으면 본문 첫 줄.
  String get label => (title != null && title!.trim().isNotEmpty)
      ? title!
      : body.split('\n').first;
}

class _TextMarkerDemoScreenState extends State<TextMarkerDemoScreen> {
  NaverMapController? _controller;

  /// 이 줌 이상이면 카드, 미만이면 원.
  static const double _cardZoom = 16.0;

  bool? _lastCardMode; // 마지막으로 그린 모드 (null=아직 안 그림)
  double _currentZoom = 15;

  // NLatLng 은 const 가 아니라 static final 로 둔다.
  static final NLatLng _center = NLatLng(37.5666, 126.979);

  // 시청 주변 목 데이터.
  static final List<_MockPost> _posts = [
    _MockPost(
      id: 'p1',
      position: NLatLng(37.5674, 126.9779),
      title: '카페 무드등',
      body: '여기에 작성한 스토리 미리보기가 두 줄까지 표시됩니다',
    ),
    _MockPost(
      id: 'p2',
      position: NLatLng(37.5659, 126.9802),
      body: '제목 없이 본문만 있는 텍스트 글입니다 두 줄까지 보여요',
    ),
    _MockPost(
      id: 'p3',
      position: NLatLng(37.5681, 126.9808),
      title: '한강 산책',
      body:
          '스토리가 길어지면 두 줄까지만 보여주고 나머지는 말줄임표로 자연스럽게 처리합니다 안녕하세요 반갑습니다 여기까지',
    ),
    _MockPost(
      id: 'p4',
      position: NLatLng(37.5650, 126.9772),
      title: '점심 맛집',
      body: '여기 국밥 진짜 맛있었어요 추천합니다',
    ),
    _MockPost(
      id: 'p5',
      position: NLatLng(37.5689, 126.9791),
      body: '오늘 날씨 너무 좋다 산책하기 딱 좋은 날',
    ),
    _MockPost(
      id: 'p6',
      position: NLatLng(37.5662, 126.9818),
      title: '전시 후기',
      body: '미술관 전시 인상 깊었던 작품 기록용 메모',
    ),
  ];

  // ── 마커 렌더 ─────────────────────────────────────────────

  Future<NOverlayImage> _cardIcon(_MockPost p) {
    return NOverlayImage.fromWidget(
      context: context,
      // 꼬리 끝점이 박스 하단 중앙(anchor)에 오도록 bottomCenter 정렬.
      size: const Size(204, 104),
      widget: SizedBox(
        width: 204,
        height: 104,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: TextMarkerCard(
            title: p.title,
            body: p.body,
            maxLines: 2,
          ),
        ),
      ),
    );
  }

  Future<NOverlayImage> _dotIcon(_MockPost p) {
    return NOverlayImage.fromWidget(
      context: context,
      size: const Size(120, 78),
      widget: SizedBox(
        width: 120,
        height: 78,
        child: Align(
          alignment: Alignment.topCenter,
          // 뱃지가 위로 삐져나오므로 top 여백.
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextMarkerDot(title: p.label, diameter: 44),
          ),
        ),
      ),
    );
  }

  Future<void> _renderMarkers({required bool cardMode}) async {
    final controller = _controller;
    if (controller == null) return;

    try {
      await controller.clearOverlays();

      final Set<NMarker> markers = {};
      for (final p in _posts) {
        final NOverlayImage icon =
            cardMode ? await _cardIcon(p) : await _dotIcon(p);
        if (!mounted) return;

        final marker = NMarker(
          id: p.id,
          position: p.position,
          icon: icon,
          // fromWidget 에 넘긴 size 와 동일하게 — 스케일 왜곡 방지.
          size: cardMode ? const Size(204, 104) : const Size(120, 78),
          // 카드: 꼬리 끝(하단 중앙). 원: 원의 하단(사진 마커 패밀리와 동일 느낌).
          // ※ 실제 좌표 정렬은 기기에서 미세 조정 권장.
          anchor: cardMode
              ? const NPoint(0.5, 1.0)
              : const NPoint(0.5, 0.67),
        );
        markers.add(marker);
      }

      if (markers.isNotEmpty) {
        await controller.addOverlayAll(markers);
      }
      _lastCardMode = cardMode;
      debugPrint('[demo] 마커 렌더 완료: ${markers.length}개 (cardMode=$cardMode)');
    } catch (e, st) {
      debugPrint('[demo] 마커 렌더 에러: $e\n$st');
    }
  }

  void _onCameraIdle() async {
    final controller = _controller;
    if (controller == null) return;
    final camera = await controller.getCameraPosition();
    final zoom = camera.zoom;
    final cardMode = zoom >= _cardZoom;
    if (mounted) setState(() => _currentZoom = zoom);
    // 모드가 바뀔 때만 다시 그린다 (불필요한 재렌더 방지).
    if (_lastCardMode != cardMode) {
      await _renderMarkers(cardMode: cardMode);
    }
  }

  // ── UI ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cardMode = _currentZoom >= _cardZoom;
    return Scaffold(
      appBar: AppBar(title: const Text('텍스트 마커 데모')),
      body: Stack(
        children: [
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition:
                  NCameraPosition(target: _center, zoom: 15),
              minZoom: 10,
              maxZoom: 20,
            ),
            onMapReady: (controller) {
              _controller = controller;
              // 첫 프레임이 그려진 뒤 렌더 — fromWidget 이 빈 이미지로 나오는 것 방지.
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                final camera = await controller.getCameraPosition();
                if (!mounted) return;
                setState(() => _currentZoom = camera.zoom);
                await _renderMarkers(cardMode: camera.zoom >= _cardZoom);
              });
            },
            onCameraIdle: _onCameraIdle,
          ),

          // 상단 상태 배너
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 16,
            right: 16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(color: Color(0x1F000000), blurRadius: 8),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    cardMode ? Icons.article_outlined : Icons.circle,
                    size: 18,
                    color: TextMarkerTokens.glyphBlue,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'zoom ${_currentZoom.toStringAsFixed(1)} · '
                    '${cardMode ? "카드(줌인)" : "원(줌아웃)"} · 임계 $_cardZoom',
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: TextMarkerTokens.titleText,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 하단 위젯 미리보기 (비트맵 아닌 실제 위젯 — QA용)
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  _Legend(
                    label: '제목+본문',
                    child: TextMarkerCard(
                      title: '카페 무드등',
                      body: '여기에 작성한 스토리 미리보기가 두 줄까지 표시됩니다',
                    ),
                  ),
                  SizedBox(width: 14),
                  _Legend(
                    label: '본문만',
                    child: TextMarkerCard(
                      body: '제목 없이 본문만 있는 텍스트 글입니다 두 줄까지 보여요',
                    ),
                  ),
                  SizedBox(width: 14),
                  _Legend(
                    label: '줌아웃 단일',
                    child: TextMarkerDot(title: '카페 무드등'),
                  ),
                  SizedBox(width: 14),
                  _Legend(
                    label: '줌아웃 클러스터',
                    child: TextMarkerDot(title: '이 근처 글 3개', count: 3),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 11,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

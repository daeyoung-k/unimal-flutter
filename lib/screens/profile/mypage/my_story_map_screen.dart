import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:get/get.dart';
import 'package:unimal/screens/map/bottom_card/relative_time.dart';
import 'package:unimal/screens/map/marker/marker_constants.dart';
import 'package:unimal/screens/map/marker/text_marker_widgets.dart';
import 'package:unimal/screens/profile/mypage/post_detail_sheet.dart';
import 'package:unimal/service/board/board_api_service.dart';
import 'package:unimal/service/board/model/board_post.dart';
import 'package:unimal/screens/map/marker/marker_image_factory.dart';
import 'package:unimal/service/user/model/user_info_model.dart';
import 'package:unimal/service/user/user_info_service.dart';
import 'package:unimal/state/auth_state.dart';
import 'package:unimal/theme/app_colors.dart';
import 'package:unimal/utils/display_title.dart';

/// 내 스토리 전용 지도 화면.
///
/// 메인 지도 탭과 달리 **내 글만** 마커로 표시한다. 마커 탭 시 상세 시트를 띄운다.
/// 마이페이지 지도 미리보기 카드(`MyStoryMapCard`) 탭으로 진입.
class MyStoryMapScreen extends StatefulWidget {
  const MyStoryMapScreen({super.key});

  @override
  State<MyStoryMapScreen> createState() => _MyStoryMapScreenState();
}

class _MyStoryMapScreenState extends State<MyStoryMapScreen> {
  final _boardApi = BoardApiService();
  final _userInfoService = UserInfoService();
  final _markerImageFactory = MarkerImageFactory();
  final _authState = Get.find<AuthState>();

  NaverMapController? _mapController;
  bool _markersRendered = false;
  // 클러스터 빌더 재사용: 마커 id → 개별 아이콘(size==1 복원), 카운트 → 버블 아이콘.
  final Map<String, NOverlayImage> _markerIcons = {};
  final Map<int, NOverlayImage> _clusterBubbleCache = {};
  // count별 합성 중인 Future — 동일 이미지 동시 합성(쓰기 경합) 방지.
  final Map<int, Future<NOverlayImage>> _clusterBubbleInflight = {};

  // 텍스트(사진 없는) 마커의 점↔카드 전환 상태 — 메인 지도와 동일한 히스테리시스.
  bool _textCardMode = false;
  final Map<String, NClusterableMarker> _textMarkerRefs = {};
  final Map<String, BoardPost> _textMarkerPosts = {};
  final Map<String, NOverlayImage> _textCardIconCache = {};

  // 선택(탭)된 마커 z-index 부스트 — 메인 지도와 동일 동작.
  static const int _selectedMarkerZIndex = 999999999;
  static const int _baseMarkerZIndex = 200000; // NMarker 기본 globalZIndex
  final Map<String, NClusterableMarker> _markerRefs = {};
  String? _highlightedMarkerId;

  List<BoardPost> _posts = [];
  UserInfoModel? _userInfo;
  bool _isLoading = true;

  // 하단 시트 세그먼트: 0 = 내 스토리, 1 = 좋아요한.
  int _segment = 0;
  int _myTotal = 0;
  int _likedTotal = 0;
  // 좋아요한 목록은 탭 처음 열 때 지연 로드.
  List<BoardPost> _likedPosts = [];
  bool _likedLoaded = false;
  bool _likedLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Future.wait 는 하나라도 던지면 통째로 reject — 그대로 두면 _isLoading 이
    // 영원히 true 로 남아 무한 스피너가 된다. 실패해도 화면은 뜨게 방어.
    List<Object?>? results;
    try {
      results = await Future.wait([
        _boardApi.getMyPostList(sortType: 'LATEST'),
        _userInfoService.getMemberInfo(_authState.accessToken.value),
        _boardApi.getMyPostTotal(),
        _boardApi.getMyLikedTotal(),
      ]);
    } catch (e, st) {
      debugPrint('[myStoryMap] 데이터 로드 실패: $e\n$st');
    }
    if (mounted) {
      setState(() {
        if (results != null) {
          _posts = (results[0] as List<BoardPost>?) ?? [];
          _userInfo = results[1] as UserInfoModel?;
          _myTotal = (results[2] as int?) ?? (_posts.length);
          _likedTotal = (results[3] as int?) ?? 0;
        }
        _isLoading = false;
      });
      // 지도가 먼저 준비됐다면(데이터보다 빨리) 이제 마커를 그린다.
      _renderMarkers();
    }
  }

  Future<void> _loadLiked() async {
    if (_likedLoaded || _likedLoading) return;
    setState(() => _likedLoading = true);
    final liked = await _boardApi.getMyLikedPostList(page: 0, size: 20);
    if (mounted) {
      setState(() {
        _likedPosts = liked;
        _likedLoaded = true;
        _likedLoading = false;
      });
    }
  }

  void _onSegmentChanged(int index) {
    if (_segment == index) return;
    setState(() => _segment = index);
    if (index == 1) _loadLiked();
  }

  // 좌표가 있는 내 글만. 서버는 위치 없는 글에 (0,0)을 주므로 그것도 제외한다.
  List<BoardPost> get _located => _posts
      .where((p) =>
          p.latitude != null &&
          p.longitude != null &&
          !(p.latitude == 0 && p.longitude == 0))
      .toList();

  Future<void> _onMapReady(NaverMapController controller) async {
    _mapController = controller;
    // 데이터가 먼저 도착했다면 지금 그린다(아직이면 _load 완료 후 그린다).
    await _renderMarkers();
  }

  /// 지도 준비 + 데이터 로드가 **둘 다** 끝났을 때 한 번만 마커를 그린다.
  /// (둘 중 늦게 끝나는 쪽에서 호출 — 비동기 순서에 관계없이 마커가 표시되도록)
  ///
  /// 마커는 메인 지도 화면과 동일한 커스텀 마커:
  /// 사진 글 = 썸네일 마커(`createMarkerImage`), 텍스트 글 = 점 마커(`createTextDotImage`),
  /// 32px + 제목 캡션. 탭 시 상세 시트.
  Future<void> _renderMarkers() async {
    final controller = _mapController;
    if (controller == null || _markersRendered) return;
    final located = _located;
    if (located.isEmpty) return;
    _markersRendered = true;

    // 같은 좌표에 뭉친 글은 줌인해도 좌표가 겹쳐 구분이 안 되므로, 메인 지도와
    // 동일하게 약 17m 반경 원형으로 흩뿌린다(jitter). 줌 16+에서 클러스터가
    // 풀리면 이 오프셋 덕분에 동일 좌표 글들이 개별 마커로 펼쳐진다.
    final jittered = _computeJitteredPositions(located);

    final colors = AppColors.of(context);
    final markers = <NClusterableMarker>{};
    for (final p in located) {
      NOverlayImage icon;
      try {
        if (p.fileInfoList.isNotEmpty) {
          final stream =
              await _markerImageFactory.getImageStream(p.fileInfoList.first.fileUrl);
          final bytes = await _markerImageFactory.createMarkerImage(stream);
          icon = await overlayImageFromBytes(bytes);
        } else {
          final bytes = await _markerImageFactory.createTextDotImage();
          icon = await overlayImageFromBytes(bytes);
        }
      } catch (_) {
        continue; // 이미지 로드 실패한 마커는 건너뛴다(메인 지도와 동일).
      }

      final id = 'mystory_${p.boardId}';
      final bool isText = p.fileInfoList.isEmpty;
      _markerIcons[id] = icon; // 클러스터 빌더 size==1 복원용 (텍스트는 점 아이콘)
      final title = displayTitle(p.title, p.content);
      final position = jittered[p.boardId]!;
      final marker = NClusterableMarker(
        id: id,
        position: position,
        icon: icon,
        size: const Size(kNormalMarkerSize, kNormalMarkerSize),
        tags: {'title': title, 'boardId': p.boardId, 'isText': isText ? '1' : '0'},
        caption: NOverlayCaption(
          text: _markerCaption(title),
          textSize: _markerCaptionTextSize,
          color: colors.textPrimary,
          haloColor: colors.background,
        ),
      );
      _markerRefs[id] = marker;
      if (isText) {
        _textMarkerRefs[id] = marker;
        _textMarkerPosts[id] = p;
      }
      // 클러스터링 비활성 줌(16+)에서 단일 마커 탭.
      // 텍스트 마커는 카드 줌 미만이면 카드가 펼쳐지도록 줌인만 (메인 지도와 동일).
      marker.setOnTapListener((NClusterableMarker _) async {
        if (!mounted) return;
        if (isText) {
          final cam = await _mapController?.getCameraPosition();
          if (cam != null && cam.zoom < kTextCardEnterZoom) {
            await _zoomToTextCard(position);
            return;
          }
        }
        if (!mounted) return;
        // 탭한 마커를 최상위로 부스트 + 시트에 안 가리는 위치로 카메라 이동.
        // 카메라는 시트와 동시에 움직이도록 await 하지 않는다.
        _applySelectionHighlight(id);
        unawaited(_moveCameraToMarker(position));
        await showPostDetailSheet(context, p.boardId);
        if (mounted) _applySelectionHighlight(null);
      });
      markers.add(marker);
    }
    if (!mounted) return;
    // 카메라를 먼저 최종 위치로 이동시킨 뒤 마커를 얹는다.
    // 마커를 먼저 그리면 fit 과정에서 줌이 바뀌며 클러스터 재병합이
    // 그대로 보여 매끄럽지 않다. (즉시 이동 — 마커 없는 상태라 티 안 남)
    await _fitCamera(
      controller,
      located.map((p) => jittered[p.boardId]!).toList(),
    );
    if (!mounted) return;
    await controller.addOverlayAll(markers);
  }

  // 공용 헬퍼 위임 — 메인 지도와 동일한 글자 수 제한.
  String _markerCaption(String title) => truncateMarkerCaption(title);

  /// 같은 좌표에 뭉친 글을 원형으로 흩뿌린 표시 좌표 맵(boardId → 좌표)을 만든다.
  /// 단일 좌표 그룹은 원좌표 그대로 둔다. 메인 지도(`map_naver.dart`)와 동일 방식 —
  /// 줌 16+에서 클러스터가 풀릴 때 동일 좌표 글들이 겹치지 않고 펼쳐지도록 한다.
  Map<String, NLatLng> _computeJitteredPositions(List<BoardPost> located) {
    const jitterRadius = 0.00015; // 위경도 약 17m
    final Map<String, List<BoardPost>> grouped = {};
    for (final p in located) {
      final key =
          '${p.latitude!.toStringAsFixed(3)},${p.longitude!.toStringAsFixed(3)}';
      grouped.putIfAbsent(key, () => []).add(p);
    }
    final Map<String, NLatLng> result = {};
    for (final group in grouped.values) {
      // boardId로 정렬해 재진입 시에도 동일한 배치(jitter 순서 안정화).
      group.sort((a, b) => a.boardId.compareTo(b.boardId));
      for (int i = 0; i < group.length; i++) {
        final p = group[i];
        if (group.length == 1) {
          result[p.boardId] = NLatLng(p.latitude!, p.longitude!);
        } else {
          final angle = 2 * pi * i / group.length;
          result[p.boardId] = NLatLng(
            p.latitude! + jitterRadius * cos(angle),
            p.longitude! + jitterRadius * sin(angle),
          );
        }
      }
    }
    return result;
  }

  /// 클러스터 마커 빌더 — "이 지역에 N개"를 보여주는 카운트 버블.
  void _buildClusterMarker(NClusterInfo info, NClusterMarker clusterMarker) {
    if (!mounted) return;
    final colors = AppColors.of(context);
    final child = info.children.isNotEmpty ? info.children.first : null;

    if (info.size <= 1) {
      // 단일 마커가 클러스터 빌더를 거치면 원래 썸네일/점 아이콘 복원.
      final icon = child != null ? _markerIcons[child.id] : null;
      if (icon != null) {
        clusterMarker.setIcon(icon);
        clusterMarker.setSize(const Size(kNormalMarkerSize, kNormalMarkerSize));
      }
      clusterMarker.setCaption(NOverlayCaption(
        text: _markerCaption((child?.tags['title'] ?? '').trim()),
        textSize: _markerCaptionTextSize,
        color: colors.textPrimary,
        haloColor: colors.background,
      ));
      final boardId = child?.tags['boardId'];
      if (boardId != null) {
        final bool isText = (child?.tags['isText'] ?? '0') == '1';
        final NLatLng? pos = child?.position;
        final String? markerId = child?.id;
        clusterMarker.setOnTapListener((_) async {
          if (!mounted) return;
          // 텍스트 마커: 카드 줌 미만이면 줌인해 카드로 펼침 (메인 지도와 동일).
          if (isText && pos != null) {
            final cam = await _mapController?.getCameraPosition();
            if (cam != null && cam.zoom < kTextCardEnterZoom) {
              await _zoomToTextCard(pos);
              return;
            }
          }
          if (!mounted) return;
          // 클러스터 줌에선 화면에 보이는 건 NClusterMarker라 둘 다 부스트.
          if (markerId != null) _applySelectionHighlight(markerId);
          try {
            clusterMarker.setGlobalZIndex(_selectedMarkerZIndex);
          } catch (_) {}
          if (pos != null) unawaited(_moveCameraToMarker(pos));
          await showPostDetailSheet(context, boardId);
          if (!mounted) return;
          _applySelectionHighlight(null);
          try {
            clusterMarker.setGlobalZIndex(_baseMarkerZIndex);
          } catch (_) {}
        });
      }
      return;
    }

    // 다중 — 카운트 버블.
    clusterMarker.setCaption(const NOverlayCaption(text: ''));
    final cached = _clusterBubbleCache[info.size];
    if (cached != null) {
      clusterMarker.setIcon(cached);
      clusterMarker.setSize(const Size(kClusterBubbleSize, kClusterBubbleSize));
    } else {
      _composeClusterBubble(info.size, clusterMarker);
    }
    // 클러스터 탭 → 클러스터 중심으로 fly 줌인(16+). 줌 16부터 클러스터링이 풀리며
    // jitter된 동일 좌표 글들이 개별 마커로 펼쳐진다. (메인 지도와 동일 동선)
    final children = info.children;
    if (children.isNotEmpty) {
      double sumLat = 0, sumLng = 0;
      for (final c in children) {
        sumLat += c.position.latitude;
        sumLng += c.position.longitude;
      }
      final center =
          NLatLng(sumLat / children.length, sumLng / children.length);
      clusterMarker.setOnTapListener((_) async {
        final controller = _mapController;
        if (controller == null) return;
        final cam = await controller.getCameraPosition();
        // 메인 지도(_clusterExpandZoom)와 동일 — 16은 클러스터가 겨우 풀리는
        // 수준이라 jitter 마커가 겹쳐 보임. 17로 당겨 개별 구분되게 한다.
        final nextZoom = cam.zoom < _clusterExpandZoom
            ? _clusterExpandZoom
            : cam.zoom;
        final update = NCameraUpdate.scrollAndZoomTo(
          target: center,
          zoom: nextZoom,
        )..setAnimation(
            animation: NCameraAnimation.fly,
            duration: const Duration(milliseconds: 600),
          );
        await controller.updateCamera(update);
      });
    }
  }

  Future<void> _composeClusterBubble(
      int count, NClusterMarker clusterMarker) async {
    if (!mounted) return;
    final colors = AppColors.of(context);
    // 같은 count 버블은 동일 PNG → 플러그인이 같은 캐시 파일에 저장한다.
    // 동시에 두 번 합성하면 같은 파일에 쓰기 경합이 나 0바이트 파일이 생기고
    // iOS 크래시로 이어진다(플러그인 이슈 #251). in-flight Future를 공유해
    // count당 합성이 한 번만 일어나게 한다.
    final future = _clusterBubbleInflight.putIfAbsent(
      count,
      () => overlayImageFromWidget(
        context: context,
        size: const Size(kClusterBubbleSize, kClusterBubbleSize),
        widget: _ClusterBubble(count: count, color: colors.primary),
      ),
    );
    final icon = await future;
    if (!mounted) return;
    _clusterBubbleCache[count] = icon;
    clusterMarker.setIcon(icon);
    clusterMarker.setSize(const Size(kClusterBubbleSize, kClusterBubbleSize));
  }

  /// 마커가 화면 세로 22% 지점, 가로 중앙에 보이도록 카메라 이동 (fly 600ms).
  /// 상세 시트가 하단을 덮어도 마커가 보이는 위치. 줌이 [_clusterExpandZoom]
  /// 미만이면 함께 줌인 — 메인 지도(_moveCameraToMarker)와 동일 알고리즘.
  Future<void> _moveCameraToMarker(NLatLng markerPos) async {
    final controller = _mapController;
    if (controller == null || !mounted) return;
    final size = MediaQuery.sizeOf(context);

    final camera = await controller.getCameraPosition();
    final currentZoom = camera.zoom;
    final targetZoom =
        currentZoom < _clusterExpandZoom ? _clusterExpandZoom : currentZoom;

    // 카메라 target을 (markerPos + (cameraTarget - desiredCoord))로 두면
    // 새 카메라에서 markerPos가 원하는 픽셀에 매핑된다. 줌이 바뀌면 오프셋을
    // 2^(currentZoom - targetZoom) 비율로 스케일.
    final desiredPixel = NPoint(size.width / 2, size.height * 0.22);
    final desiredCoord = await controller.screenLocationToLatLng(desiredPixel);

    var dLat = camera.target.latitude - desiredCoord.latitude;
    var dLng = camera.target.longitude - desiredCoord.longitude;
    if (targetZoom != currentZoom) {
      final scale = pow(2, currentZoom - targetZoom).toDouble();
      dLat *= scale;
      dLng *= scale;
    }

    final adjustedTarget = NLatLng(
      markerPos.latitude + dLat,
      markerPos.longitude + dLng,
    );
    final update = NCameraUpdate.scrollAndZoomTo(
      target: adjustedTarget,
      zoom: targetZoom,
    )..setAnimation(
        animation: NCameraAnimation.fly,
        duration: const Duration(milliseconds: 600),
      );
    await controller.updateCamera(update);
  }

  /// 선택된 마커를 z-index 부스트 + (사진 마커) 확대로 강조. [markerId]가
  /// null이면 강조 해제. 메인 지도(_applySelectionHighlight)와 동일한 방식.
  void _applySelectionHighlight(String? markerId) {
    final prevId = _highlightedMarkerId;
    if (prevId != null && prevId != markerId) {
      final prev = _markerRefs[prevId];
      if (prev != null) {
        try {
          prev.setGlobalZIndex(_baseMarkerZIndex);
        } catch (_) {/* 오버레이가 이미 제거된 경우 무시 */}
        // 사진 마커만 원래 크기로 복원 (텍스트 마커는 카드/점 가변이라 제외)
        if (!_textMarkerRefs.containsKey(prevId)) {
          try {
            prev.setSize(const Size(kNormalMarkerSize, kNormalMarkerSize));
          } catch (_) {/* same */}
        }
      }
    }
    _highlightedMarkerId = markerId;
    if (markerId != null) {
      final marker = _markerRefs[markerId];
      if (marker != null) {
        try {
          marker.setGlobalZIndex(_selectedMarkerZIndex);
        } catch (_) {/* same */}
        // 선택 강조: 사진 마커는 살짝 확대 (메인 지도와 동일 방식)
        if (!_textMarkerRefs.containsKey(markerId)) {
          try {
            marker.setSize(const Size(
                kNormalMarkerSize * kSelectedMarkerScale,
                kNormalMarkerSize * kSelectedMarkerScale));
          } catch (_) {/* same */}
        }
      }
    }
  }

  // ── 텍스트 마커 점↔카드 전환 (메인 지도와 동일 동작) ──────────────────

  /// 텍스트 마커/클러스터 탭 시 카드가 펼쳐지도록 줌인.
  Future<void> _zoomToTextCard(NLatLng target) async {
    final controller = _mapController;
    if (controller == null) return;
    final update = NCameraUpdate.scrollAndZoomTo(
      target: target,
      zoom: kTextCardCameraZoom,
    )..setAnimation(
        animation: NCameraAnimation.fly,
        duration: const Duration(milliseconds: 600),
      );
    await controller.updateCamera(update);
  }

  /// 카메라 정지 시 텍스트 카드 모드 전환 판단 — 히스테리시스로 경계 깜빡임 방지.
  Future<void> _onCameraIdle() async {
    final controller = _mapController;
    if (controller == null || _textMarkerRefs.isEmpty) return;
    final cam = await controller.getCameraPosition();
    if (!mounted) return;
    final bool next = _textCardMode
        ? cam.zoom >= kTextCardExitZoom
        : cam.zoom >= kTextCardEnterZoom;
    if (next == _textCardMode) return;
    _textCardMode = next;
    await _applyTextCardMode(next);
  }

  /// 텍스트 마커 아이콘을 점↔카드로 일괄 교체.
  /// 마커 재생성 없이 setIcon/setSize/setCaption만 갱신 — 깜빡임 최소화.
  Future<void> _applyTextCardMode(bool cardMode) async {
    if (!mounted) return;
    final colors = AppColors.of(context);
    for (final entry in _textMarkerRefs.entries) {
      final id = entry.key;
      final marker = entry.value;
      final post = _textMarkerPosts[id];
      if (post == null) continue;
      try {
        if (cardMode) {
          final icon = _textCardIconCache[id] ?? await _buildTextCardIcon(post);
          _textCardIconCache[id] = icon;
          if (!mounted) return;
          marker.setIcon(icon);
          marker.setSize(kTextCardSize);
          // 카드에 제목/본문 포함 → 하단 캡션 중복 방지.
          marker.setCaption(const NOverlayCaption(text: ''));
        } else {
          final dot = _markerIcons[id];
          if (dot != null) marker.setIcon(dot);
          marker.setSize(const Size(kNormalMarkerSize, kNormalMarkerSize));
          marker.setCaption(NOverlayCaption(
            text: _markerCaption(displayTitle(post.title, post.content)),
            textSize: _markerCaptionTextSize,
            color: colors.textPrimary,
            haloColor: colors.background,
          ));
        }
      } catch (_) {
        // 오버레이가 네이티브에서 제거된 경우 등 — 개별 마커 실패는 무시.
      }
    }
  }

  /// 텍스트 글 줌인 카드 아이콘 — 꼬리 끝이 하단 중앙(anchor 0.5,1.0)에 오도록
  /// bottomCenter 정렬. 제목 없으면 본문만 카드. (메인 지도와 동일 위젯)
  Future<NOverlayImage> _buildTextCardIcon(BoardPost post) {
    final String? title =
        post.title.trim().isNotEmpty ? post.title.trim() : null;
    return overlayImageFromWidget(
      context: context,
      size: kTextCardSize,
      widget: SizedBox(
        width: kTextCardSize.width,
        height: kTextCardSize.height,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: TextBubbleMarker(
            title: title,
            body: post.content,
            time: relativeTimeFromString(post.createdAt),
            maxLines: 2,
          ),
        ),
      ),
    );
  }

  // 진입 시 overview 줌 상한. 클러스터링은 줌 15까지 동작하므로(16+는 펼침)
  // 이 값 이하에서 시작해야 "이 지역 N개" 묶음이 보인다.
  static const double _maxFitZoom = 13.0;

  // 클러스터 탭 줌·캡션 폰트 — marker_constants.dart 공용 값 (메인 지도와 동일).
  static const double _clusterExpandZoom = kClusterExpandZoom;
  static const double _markerCaptionTextSize = kMarkerCaptionTextSize;

  /// 마커 추가 **전에** 호출된다 — 즉시 이동(무애니메이션)이라 빈 지도에서
  /// 카메라가 움직여도 사용자에게는 처음부터 최종 위치로 보인다.
  Future<void> _fitCamera(
      NaverMapController controller, List<NLatLng> points) async {
    if (points.length == 1) {
      await controller.updateCamera(
        NCameraUpdate.scrollAndZoomTo(target: points.first, zoom: _maxFitZoom)
          ..setAnimation(
              animation: NCameraAnimation.none, duration: Duration.zero),
      );
      return;
    }

    final pad = MediaQuery.paddingOf(context);
    final bounds = NLatLngBounds.from(points);
    await controller.updateCamera(
      NCameraUpdate.fitBounds(
        bounds,
        padding: EdgeInsets.only(
          top: pad.top + 72,
          bottom: 72,
          left: 56,
          right: 56,
        ),
      )..setAnimation(
          animation: NCameraAnimation.none, duration: Duration.zero),
    );
    // fitBounds가 너무 깊게 줌인하면 상한으로 당긴다.
    final cam = await controller.getCameraPosition();
    if (cam.zoom > _maxFitZoom) {
      await controller.updateCamera(
        NCameraUpdate.scrollAndZoomTo(target: cam.target, zoom: _maxFitZoom)
          ..setAnimation(
              animation: NCameraAnimation.none, duration: Duration.zero),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition: NCameraPosition(
                target: const NLatLng(37.5666, 126.979),
                zoom: 11,
              ),
              mapType: isDark ? NMapType.navi : NMapType.basic,
              nightModeEnable: isDark,
              // POI 심볼 축소 — 공용 상수 (메인 지도와 동일, 캡션 착시 방지).
              symbolScale: kMapSymbolScale,
              consumeSymbolTapEvents: false,
            ),
            clusterOptions: NaverMapClusteringOptions(
              // 줌 15까지 묶고 16+ 부터 개별 마커로 펼침.
              enableZoomRange: const NInclusiveRange(0, 15),
              animationDuration: Duration.zero,
              // 병합 거리 — 공용 상수 (메인 지도와 동일).
              mergeStrategy: const NClusterMergeStrategy(
                willMergedScreenDistance: kClusterMergeDistances,
              ),
              clusterMarkerBuilder: _buildClusterMarker,
            ),
            onMapReady: _onMapReady,
            // 텍스트 마커 점↔카드 전환 감지 (메인 지도와 동일).
            onCameraIdle: _onCameraIdle,
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopBar(colors),
          ),
          // 하단 시트 — 끌어올리면 내 스토리/좋아요한 목록.
          if (!_isLoading && _posts.isNotEmpty) _buildBottomSheet(colors),
          if (_isLoading)
            Positioned.fill(
              child: ColoredBox(
                color: colors.background.withValues(alpha: 0.55),
                child: Center(
                  child: CircularProgressIndicator(
                      color: colors.primaryStrong, strokeWidth: 2),
                ),
              ),
            ),
          if (!_isLoading && _posts.isEmpty) _buildEmpty(colors),
        ],
      ),
    );
  }

  Widget _buildBottomSheet(AppColors colors) {
    return DraggableScrollableSheet(
      initialChildSize: 0.32,
      minChildSize: 0.14,
      maxChildSize: 0.9,
      snap: true,
      snapSizes: const [0.32, 0.9],
      builder: (context, scrollController) {
        final isMy = _segment == 0;
        final list = isMy ? _posts : _likedPosts;
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: 16,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          // 핸들·세그먼트를 같은 스크롤뷰 안에 둬야 그 영역을 잡아도 시트가 끌린다
          // (DraggableScrollableSheet는 controller가 붙은 스크롤러로만 드래그됨).
          clipBehavior: Clip.antiAlias,
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              const SizedBox(height: 10),
              // 드래그 핸들
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildSegmentToggle(colors),
              const SizedBox(height: 12),
              if (!isMy && _likedLoading)
                Padding(
                  padding: const EdgeInsets.only(top: 36, bottom: 36),
                  child: Center(
                    child: CircularProgressIndicator(
                        color: colors.primaryStrong, strokeWidth: 2),
                  ),
                )
              else if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 48, bottom: 48),
                  child: Center(
                    child: Text(
                      isMy ? '아직 스토리가 없어요' : '좋아요한 스토리가 없어요',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Pretendard',
                        color: colors.textTertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              else
                for (final post in list)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildListRow(colors, post),
                  ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSegmentToggle(AppColors colors) {
    Widget seg(int index, String label, int count) {
      final selected = _segment == index;
      return Expanded(
        child: GestureDetector(
          onTap: () => _onSegmentChanged(index),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: selected ? colors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: colors.shadow,
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              '$label $count',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFamily: 'Pretendard',
                color: selected ? colors.textPrimary : colors.textTertiary,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            seg(0, '내 스토리', _myTotal),
            seg(1, '좋아요한', _likedTotal),
          ],
        ),
      ),
    );
  }

  /// 리스트에서 글 탭 — 해당 마커가 있으면(위치 있는 내 글) 마커 탭과 동일하게
  /// 카메라 이동 + 최상위 부스트 후 상세 시트. 마커 없으면(위치 없는 글,
  /// 좋아요한 글) 시트만 연다.
  Future<void> _onListRowTap(BoardPost post) async {
    final id = 'mystory_${post.boardId}';
    final marker = _markerRefs[id];
    if (marker == null) {
      await showPostDetailSheet(context, post.boardId);
      return;
    }
    _applySelectionHighlight(id);
    unawaited(_moveCameraToMarker(marker.position));
    await showPostDetailSheet(context, post.boardId);
    if (mounted) _applySelectionHighlight(null);
  }

  Widget _buildListRow(AppColors colors, BoardPost post) {
    final hasImage = post.fileInfoList.isNotEmpty;
    return GestureDetector(
      onTap: () => _onListRowTap(post),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: colors.surfaceVariant,
              ),
              clipBehavior: Clip.antiAlias,
              child: hasImage
                  ? CachedNetworkImage(
                      imageUrl: post.fileInfoList.first.fileUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: colors.surfaceVariant),
                      errorWidget: (_, __, ___) => Icon(
                        Icons.image_not_supported_outlined,
                        color: colors.primary,
                        size: 24,
                      ),
                    )
                  : Center(
                      child: Icon(Icons.sticky_note_2_outlined,
                          color: colors.primary, size: 26),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayTitle(post.title, post.content),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Pretendard',
                      color: colors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 12, color: colors.textTertiary),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          post.streetName.isNotEmpty
                              ? post.streetName
                              : '위치 정보 없음',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Pretendard',
                            color: colors.textTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    relativeTimeFromString(post.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Pretendard',
                      color: colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.favorite, size: 12, color: colors.accentCoral),
                      const SizedBox(width: 3),
                      Text(
                        post.likeCount.toString(),
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Pretendard',
                          color: colors.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.chat_bubble_outline,
                          size: 12, color: colors.primarySoft),
                      const SizedBox(width: 3),
                      Text(
                        post.replyCount.toString(),
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Pretendard',
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(AppColors colors) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(
          children: [
            _circleButton(
              colors: colors,
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Get.back(),
            ),
            const SizedBox(width: 10),
            // 프로필 칩 — '지도의 저자'를 지도 위에 띄움(아바타 + 닉네임 + 스토리 수).
            Flexible(child: _buildProfileChip(colors)),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileChip(AppColors colors) {
    final nickname = _userInfo?.nickname.isNotEmpty == true
        ? _userInfo!.nickname
        : (_userInfo?.name.isNotEmpty == true ? _userInfo!.name : '나');
    final hasImage =
        _userInfo?.profileImage != null && _userInfo!.profileImage!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipOval(
            child: SizedBox(
              width: 32,
              height: 32,
              child: hasImage
                  ? CachedNetworkImage(
                      imageUrl: _userInfo!.profileImage!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          _buildAvatarLetter(nickname, colors),
                    )
                  : _buildAvatarLetter(nickname, colors),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              nickname,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFamily: 'Pretendard',
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarLetter(String name, AppColors colors) {
    return Container(
      color: colors.primaryWash,
      alignment: Alignment.center,
      child: Text(
        name[0],
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          fontFamily: 'Pretendard',
          color: colors.primaryStrong,
        ),
      ),
    );
  }

  Widget _circleButton({
    required AppColors colors,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 18, color: colors.textPrimary),
      ),
    );
  }

  Widget _buildEmpty(AppColors colors) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.place_outlined, size: 40, color: colors.textMuted),
            const SizedBox(height: 12),
            Text(
              '지도에 표시할 스토리가 없어요',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFamily: 'Pretendard',
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '위치가 담긴 스토리를 남기면 여기에 모여요',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Pretendard',
                color: colors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 클러스터(2개 이상) 마커용 카운트 버블. 지도 위 가독성을 위해 화이트 링은
/// 양 테마 공통으로 흰색 고정(`story_marker`와 동일한 의도).
class _ClusterBubble extends StatelessWidget {
  final int count;
  final Color color;
  const _ClusterBubble({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          fontFamily: 'Pretendard',
        ),
      ),
    );
  }
}

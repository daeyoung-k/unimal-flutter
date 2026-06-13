import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:unimal/screens/map/bottom_card/map_bottom_card.dart';
import 'package:unimal/screens/map/marker/text_marker_widgets.dart';
import 'package:unimal/service/board/board_api_service.dart';
import 'package:unimal/service/image/image_service.dart';
import 'package:unimal/service/map/models/map_post.dart';
import 'package:unimal/service/map/naver_search_service.dart';
import 'package:unimal/state/nav_controller.dart';
import 'package:unimal/theme/app_colors.dart';
import 'package:unimal/utils/display_title.dart';

class MapNaverScreens extends StatefulWidget {
  const MapNaverScreens({super.key});

  @override
  State<MapNaverScreens> createState() => _MapNaverScreensState();
}

class _MapNaverScreensState extends State<MapNaverScreens>
    with WidgetsBindingObserver {
  NaverMapController? _mapController;
  final ImageService _imageService = ImageService();
  final NaverSearchService _searchService = NaverSearchService();
  final BoardApiService _boardApiService = BoardApiService();
  final List<String> _mapMarkerIds = [];
  // 마커 ID → NOverlayImage 캐시. 클러스터 마커가 score 최상위 마커 이미지를 재사용할 때 사용.
  final Map<String, NOverlayImage> _markerIconCache = {};
  // 마커 ID → base bytes 캐시. 클러스터 뱃지 합성에 재사용.
  final Map<String, Uint8List> _markerBytesCache = {};
  // (topId, size) → 합성된 클러스터 아이콘 캐시.
  final Map<String, NOverlayImage> _clusterIconCache = {};
  // 현재 진행 중인 클러스터의 (topId → 마지막 빌드 시점의 size).
  // 비동기 합성 결과가 늦게 도착할 때 stale 적용 방지.
  final Map<String, int> _clusterCurrentSize = {};
  // 마커 ID → 마커 객체. 선택 시 z-index 부스트를 위해 참조 유지.
  final Map<String, NClusterableMarker> _markerRefs = {};
  // 마커 ID → 기본 z-index (score 기반). 선택 해제 시 이 값으로 복원.
  final Map<String, int> _markerBaseZIndex = {};
  // 텍스트 마커 ID → 마지막으로 그린 모드(true=카드/줌인, false=원/줌아웃).
  // 줌이 임계(16)를 넘나들면 모드가 바뀌므로 재생성 판단에 사용.
  final Map<String, bool> _textMarkerCardMode = {};
  // 화면 전체 텍스트 마커 표현 모드(true=카드, false=점). 줌 히스테리시스로 갱신.
  // 경계 줌에서 카메라가 미세하게 흔들려도 점↔카드가 깜빡이지 않게 하는 핵심 상태.
  bool _textCardMode = false;
  // 현재 z-index 부스트되어 있는 마커 ID (한 번에 1개만 부스트).
  String? _highlightedMarkerId;
  // 선택 마커가 사용하는 z-index. score 기반(약 200,000 + score)보다 충분히 큰 값.
  static const int _selectedMarkerZIndex = 999999999;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<NaverLocalSearchResult> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;

  // POI 심볼 탭 관련 상태
  NSymbolInfo? _selectedSymbol;
  NaverLocalSearchResult? _selectedPlace;
  bool _isLoadingPlace = false;

  // 커스텀 마커 탭 관련 상태
  List<List<MapPost>> _postGroups = [];
  int? _selectedGroupIndex;
  bool _isCardExpanded = false;
  List<MapPost> get _selectedPosts =>
      _selectedGroupIndex == null ? const [] : _postGroups[_selectedGroupIndex!];

  // 카드 드래그 관련 상태
  double _cardDragOffset = 0.0;

  // 주변 스토리 조회 버튼 관련 상태
  bool _mapInitialized = false;
  NLatLng? _lastQueriedTarget;
  double _lastQueriedZoom = 15;

  // 카메라 이동 자동 조회 — debounce + lock
  Timer? _cameraDebounce;
  bool _isLoadingMarkers = false;
  // refreshMap() 호출 시 로드가 진행 중이면 완료 후 강제 새로고침을 실행하기 위한 플래그
  bool _pendingForceRefresh = false;

  Worker? _pendingLocationWorker;

  // 검색바 실측 — 카드 최대 높이를 검색바 바로 아래까지로 정확히 제한하기 위해
  // post-frame에서 RenderBox 위치를 측정한다. 0이면 아직 미측정.
  final GlobalKey _searchBarKey = GlobalKey();
  double _searchBarBottom = 0;

  static const _searchMarkerId = 'search_result_marker';
  static const _dismissThreshold = 80.0;
  bool _searchMarkerAdded = false;

  // 마커 크기 — 한 곳에서 조절
  static const _normalMarkerSize = 32.0; // 일반(단일) 마커
  static const _clusterMarkerSize = 42.0; // 클러스터(2개 이상 합쳐진) 마커
  // 텍스트 카드 마커 크기 (fromWidget size 와 NMarker size 를 동일하게 — 스케일 왜곡 방지)
  // 줌아웃 점은 사진 마커처럼 _normalMarkerSize 사용(바이트 이미지 200x200 → 스케일).
  static const Size _textCardSize = Size(204, 110); // 줌인 카드 (꼬리 끝=하단 중앙)
  // 텍스트 마커/클러스터 탭 시 줌인 목표 (카드가 펼쳐지는 17.5).
  static const double _textCardCameraZoom = 17.5;
  // 텍스트 마커 표현(점↔카드) 전환 히스테리시스.
  // enter 이상으로 줌인하면 카드로, 그 후 exit 미만으로 줌아웃해야 점으로 복귀.
  // 단일 임계값(17.5)을 쓰면 파킹 줌과 경계가 겹쳐 카메라 미세 흔들림에 깜빡였다.
  // enter(17.3)는 파킹 줌(17.5)보다 살짝 낮춰 fly 언더슈트(17.49)에도 카드 진입 보장.
  static const double _textCardEnterZoom = 17.3;
  static const double _textCardExitZoom = 16.8;

  // 백엔드 ZoomLevel enum과 동기화. postLimit = 해당 줌에서 서버가 반환하는 최대 게시글 수.
  static const _zoomPostLimit = {
    10: 30, 11: 30, 12: 30,
    13: 40, 14: 40,
    15: 50, 16: 50, 17: 50,
    18: 100, 19: 100, 20: 100,
  };

  bool get _isAnyCardOpen => _selectedSymbol != null || _selectedPosts.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pendingLocationWorker = ever(
      Get.find<NavController>().pendingMapLat,
      (_) => _applyPendingLocation(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureSearchBar());
  }

  void _measureSearchBar() {
    if (!mounted) return;
    final ctx = _searchBarKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final offset = box.localToGlobal(Offset.zero);
    final bottom = offset.dy + box.size.height;
    if (bottom != _searchBarBottom) {
      setState(() => _searchBarBottom = bottom);
    }
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    if (!mounted) return;
    // 다크모드 토글 시 마커 캡션 색이 즉시 반영되도록 모든 마커 재로드.
    // 캐시 일괄 비움(이미지 fetch 다시 발생) — 토글 빈도 낮음을 가정한 단순 전략.
    // MediaQuery 가 새 brightness로 갱신된 다음 frame에 실행 — 안 그러면 이전
    // brightness 값으로 캡션 색이 결정되어 반대로 적용되는 케이스 있음.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _reloadMarkersForBrightnessChange();
    });
  }

  Future<void> _reloadMarkersForBrightnessChange() async {
    if (_mapController == null) return;
    for (final id in _mapMarkerIds.toList()) {
      try {
        _mapController!.deleteOverlay(
          NOverlayInfo(type: NOverlayType.clusterableMarker, id: id),
        );
      } catch (_) {}
    }
    _mapMarkerIds.clear();
    _markerRefs.clear();
    _markerBaseZIndex.clear();
    _textMarkerCardMode.clear();
    _markerIconCache.clear();
    _markerBytesCache.clear();
    _clusterIconCache.clear();
    _clusterCurrentSize.clear();
    _highlightedMarkerId = null;

    // 마지막 조회 위치 기준으로 재로드. 없으면 현재 카메라 기준.
    final target = _lastQueriedTarget;
    if (target != null) {
      await _loadMapMarkers(
        target.latitude,
        target.longitude,
        _lastQueriedZoom.round(),
        rawZoom: _lastQueriedZoom,
      );
    } else {
      final camera = await _mapController!.getCameraPosition();
      if (!mounted) return;
      await _loadMapMarkers(
        camera.target.latitude,
        camera.target.longitude,
        camera.zoom.round(),
        rawZoom: camera.zoom,
      );
    }
  }

  void _applyPendingLocation() {
    final nav = Get.find<NavController>();
    final lat = nav.pendingMapLat.value;
    final lng = nav.pendingMapLng.value;
    if (lat == null || lng == null) return;
    debugPrint('[map] _applyPendingLocation → (${lat.toStringAsFixed(5)}, '
        '${lng.toStringAsFixed(5)}) zoom=16');
    if (_mapController != null) {
      _mapController!.updateCamera(
        NCameraUpdate.scrollAndZoomTo(target: NLatLng(lat, lng), zoom: 16),
      );
      _loadMapMarkers(lat, lng, 16);
    }
    nav.pendingMapLat.value = null;
    nav.pendingMapLng.value = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pendingLocationWorker?.dispose();
    _debounce?.cancel();
    _cameraDebounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void refreshMap() {
    _cameraDebounce?.cancel();
    if (_isLoadingMarkers) {
      // 현재 로드가 끝난 뒤 강제 새로고침 — 마커 삭제 후 skipped 되는 race 방지
      _pendingForceRefresh = true;
      return;
    }
    _doForceRefresh();
  }

  Future<void> _doForceRefresh() async {
    if (_mapController == null) return;
    // 기존 마커 전부 제거 — 수정된 게시글 반영을 위해 재사용 없이 전체 재렌더
    for (final id in _mapMarkerIds.toList()) {
      try {
        _mapController!.deleteOverlay(
          NOverlayInfo(type: NOverlayType.clusterableMarker, id: id),
        );
      } catch (_) {}
    }
    _mapMarkerIds.clear();
    _markerRefs.clear();
    _markerBaseZIndex.clear();
    _textMarkerCardMode.clear();
    _markerIconCache.clear();
    _markerBytesCache.clear();
    _clusterIconCache.clear();
    _clusterCurrentSize.clear();
    _highlightedMarkerId = null;

    final camera = await _mapController!.getCameraPosition();
    if (!mounted) return;
    _lastQueriedTarget = null;
    _loadMapMarkers(
      camera.target.latitude,
      camera.target.longitude,
      camera.zoom.round(),
      rawZoom: camera.zoom,
    );
  }

  Future<void> _moveToCurrentLocationOrDefault() async {
    const seoulCityHall = NLatLng(37.5666, 126.979);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _loadMapMarkers(seoulCityHall.latitude, seoulCityHall.longitude, 15);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        try {
          permission = await Geolocator.requestPermission();
        } on PermissionRequestInProgressException {
          permission = await Geolocator.checkPermission();
        }
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _loadMapMarkers(seoulCityHall.latitude, seoulCityHall.longitude, 15);
        return;
      }

      Position? position;
      final gpsStart = DateTime.now();
      try {
        debugPrint('[map] GPS getCurrentPosition start (timeLimit 5s)');
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 5),
        );
        final ms = DateTime.now().difference(gpsStart).inMilliseconds;
        debugPrint('[map] GPS ok (${ms}ms) lat=${position.latitude.toStringAsFixed(5)} '
            'lng=${position.longitude.toStringAsFixed(5)}');
      } catch (e) {
        final ms = DateTime.now().difference(gpsStart).inMilliseconds;
        debugPrint('[map] GPS failed (${ms}ms) $e → tryLastKnown');
        position = await Geolocator.getLastKnownPosition();
        if (position != null) {
          debugPrint('[map] lastKnown ok lat=${position.latitude.toStringAsFixed(5)} '
              'lng=${position.longitude.toStringAsFixed(5)}');
        } else {
          debugPrint('[map] lastKnown null');
        }
      }

      if (!mounted) return;
      if (position != null) {
        debugPrint('[map] updateCamera → (${position.latitude.toStringAsFixed(5)}, '
            '${position.longitude.toStringAsFixed(5)}) zoom=15');
        _mapController?.updateCamera(
          NCameraUpdate.scrollAndZoomTo(
            target: NLatLng(position.latitude, position.longitude),
            zoom: 15,
          ),
        );
        _loadMapMarkers(position.latitude, position.longitude, 15);
      } else {
        debugPrint('[map] fallback → seoulCityHall');
        _loadMapMarkers(seoulCityHall.latitude, seoulCityHall.longitude, 15);
      }
    } catch (e) {
      debugPrint('[map] _moveToCurrentLocationOrDefault outer catch: $e → fallback');
      if (mounted) {
        _loadMapMarkers(seoulCityHall.latitude, seoulCityHall.longitude, 15);
      }
    }
  }

  Future<void> _loadMapMarkers(double latitude, double longitude, int zoom,
      {double? rawZoom}) async {
    if (_mapController == null) {
      debugPrint('[map] _loadMapMarkers skipped (controller null)');
      return;
    }
    if (_isLoadingMarkers) {
      debugPrint('[map] _loadMapMarkers skipped (already loading) '
          '→ (${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}) z=$zoom');
      return; // 중복 호출 방지
    }
    debugPrint('[map] _loadMapMarkers start '
        '(${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}) z=$zoom');
    _isLoadingMarkers = true;
    // 의도적 조회 — 이 호출 직후 카메라가 같은 좌표로 이동하며 onCameraIdle이
    // 다시 trigger될 때, 변화량 비교에서 걸려 자동 재조회가 발동하지 않도록
    // 사전에 갱신. Android에서 의도/자동 _loadMapMarkers가 연속 호출될 때
    // native overlay race("overlay can't found")가 발생하는 원인이었다.
    _lastQueriedTarget = NLatLng(latitude, longitude);
    // 실제 카메라 줌(소수)을 저장 — 반올림 정수를 쓰면 경계(17.5) 비교가 불안정해진다.
    _lastQueriedZoom = rawZoom ?? zoom.toDouble();
    try {
      await _loadMapMarkersInternal(latitude, longitude, zoom, rawZoom: rawZoom);
    } finally {
      _isLoadingMarkers = false;
      // refreshMap()이 로드 중에 호출됐다면 지금 실행
      if (_pendingForceRefresh && mounted) {
        _pendingForceRefresh = false;
        _doForceRefresh();
      }
    }
  }

  Future<void> _loadMapMarkersInternal(
      double latitude, double longitude, int zoom,
      {double? rawZoom}) async {
    // await 이후 context 사용을 피하기 위해 함수 시작 시점에 캡처.
    // 다크모드 토글 시 기존 마커는 그대로, 다음 재조회부터 새 색 반영.
    final captionTokens = AppColors.of(context);
    // 재조회 직전: 사용자가 현재 선택한 마커의 대표 ID 저장
    String? prevSelectedPostId;
    if (_selectedGroupIndex != null &&
        _selectedGroupIndex! >= 0 &&
        _selectedGroupIndex! < _postGroups.length) {
      prevSelectedPostId = _postGroups[_selectedGroupIndex!].first.id;
    }

    // 응답 대기 동안 기존 마커는 그대로 유지 (깜빡임 방지)
    final apiStart = DateTime.now();
    debugPrint('[map] API getMapLocationPosts start '
        '(${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}) z=$zoom');
    final posts = await _boardApiService.getMapLocationPosts(
      latitude: latitude,
      longitude: longitude,
      zoom: zoom,
    );
    debugPrint('[map] API done (${DateTime.now().difference(apiStart).inMilliseconds}ms) '
        'returned ${posts.length} posts');
    if (!mounted) return;

    // 같은 좌표끼리 그룹핑 (jitter 오프셋 결정용)
    final Map<String, List<MapPost>> grouped = {};
    for (final post in posts) {
      final key = '${post.latitude.toStringAsFixed(3)},${post.longitude.toStringAsFixed(3)}';
      grouped.putIfAbsent(key, () => []).add(post);
    }
    // 그룹 내 score 내림차순 (jitter 순서 안정화)
    for (final list in grouped.values) {
      list.sort((a, b) => b.score.compareTo(a.score));
    }

    // 점진적 표시: 같은 좌표 그룹이 너무 크면 상위 N개만 jitter로 표시.
    // 나머지는 클러스터링으로 줌인 시 펼쳐지도록 위임.
    const jitterRadius = 0.00015; // 위경도 약 17m
    // 백엔드 ZoomLevel.postLimit 기준 — 서버가 이미 해당 줌에서 최대 N개만 반환하므로
    // 클라이언트 jitter 한도도 같은 값으로 맞춰 불필요한 추가 컷 방지.
    final maxJitterPerGroup = _zoomPostLimit[zoom] ?? 50;
    final List<({MapPost post, NLatLng position})> markerData = [];
    for (final group in grouped.values) {
      // score 상위 N개까지만 표시
      final visible = group.length <= maxJitterPerGroup
          ? group
          : group.sublist(0, maxJitterPerGroup);
      for (int i = 0; i < visible.length; i++) {
        final post = visible[i];
        NLatLng pos;
        if (visible.length == 1) {
          pos = NLatLng(post.latitude, post.longitude);
        } else {
          final angle = 2 * pi * i / visible.length;
          pos = NLatLng(
            post.latitude + jitterRadius * cos(angle),
            post.longitude + jitterRadius * sin(angle),
          );
        }
        markerData.add((post: post, position: pos));
      }
    }

    // 새 결과의 마커 ID 집합 (게시글 id 1:1)
    final newMarkerIds = markerData.map((m) => m.post.id).toSet();
    debugPrint('[map] markerData built: ${markerData.length} markers '
        '(grouped from ${posts.length} posts)');

    // 1) 기존에 있고 새에 없는 마커만 제거
    int deletedCount = 0;
    for (final id in _mapMarkerIds.toList()) {
      if (!newMarkerIds.contains(id)) {
        try {
          _mapController!.deleteOverlay(
            NOverlayInfo(type: NOverlayType.clusterableMarker, id: id),
          );
        } catch (_) {}
        _mapMarkerIds.remove(id);
        _markerIconCache.remove(id);
        _markerBytesCache.remove(id);
        _clusterIconCache.removeWhere((key, _) => key.startsWith('${id}_'));
        _markerRefs.remove(id);
        _markerBaseZIndex.remove(id);
        _textMarkerCardMode.remove(id);
        // 부스트되어 있던 마커가 사라지면 하이라이트 상태도 해제
        if (_highlightedMarkerId == id) {
          _highlightedMarkerId = null;
        }
        deletedCount++;
      }
    }
    if (deletedCount > 0) {
      debugPrint('[map] deleted $deletedCount stale markers');
    }

    // 2) 각 게시글마다 마커 + single-post visibleGroup 추가
    final List<List<MapPost>> visibleGroups = [];
    // 신규 마커는 한 번에 addOverlayAll로 추가한다.
    // 한 개씩 addOverlay 하면 native가 매 호출마다 reclustering(release→retain)을
    // 수행하면서 빌더 이벤트가 N번 발생하고, 이전 이벤트에서 시작된
    // lSyncClusterMarker가 도착할 때 해당 클러스터가 이미 release되어
    // "overlay can't found" race 가 일어남 (Android 한정).
    // addOverlayAll은 native에서 1번의 reclustering으로 마무리되어 race 윈도우 제거.
    final Set<NClusterableMarker> markersToAdd = {};
    final List<String> markerIdsToAdd = [];

    for (final data in markerData) {
      final topPost = data.post;
      final pos = data.position;

      final bool isTextPost = topPost.fileInfoList.isEmpty;
      // 텍스트 마커: 점↔카드 전환은 줌 히스테리시스로 결정(경계 깜빡임 방지).
      // 단일 임계값(zoom>=18) 대신 enter/exit 밴드를 둬 카메라가 경계에 멈춰도 안정.
      final bool textCardMode = _resolveTextCardMode(rawZoom ?? zoom.toDouble());

      // 이미 화면에 있는 마커 → 재사용.
      // 단, 텍스트 마커는 줌 모드(카드↔원)가 바뀌었으면 제거 후 아래에서 재생성한다.
      // (사진 마커는 줌에 따라 모양이 안 바뀌므로 그대로 재사용 — 기존 동작 보존)
      if (_mapMarkerIds.contains(topPost.id)) {
        final bool needsRebuild =
            isTextPost && _textMarkerCardMode[topPost.id] != textCardMode;
        if (!needsRebuild) {
          visibleGroups.add([topPost]);
          continue;
        }
        // 모드 변경 → 제거하고 fall-through 하여 재생성
        try {
          _mapController!.deleteOverlay(
            NOverlayInfo(type: NOverlayType.clusterableMarker, id: topPost.id),
          );
        } catch (_) {}
        _mapMarkerIds.remove(topPost.id);
        _markerIconCache.remove(topPost.id);
        _markerRefs.remove(topPost.id);
        _markerBaseZIndex.remove(topPost.id);
      }

      // 신규(또는 모드 변경) 마커 생성
      NOverlayImage? icon;
      Uint8List? baseBytes;
      Size markerSize = const Size(_normalMarkerSize, _normalMarkerSize);
      bool suppressCaption = false;

      if (!isTextPost) {
        // ── 사진 글: 기존 이미지 마커 (변경 없음) ──
        try {
          final firstUrl = topPost.fileInfoList.first.fileUrl;
          final stream = await _imageService.getImageStream(firstUrl);
          baseBytes = await _imageService.createMarkerImage(stream);
          icon = await NOverlayImage.fromByteArray(baseBytes);
        } catch (_) {
          continue;
        }
      } else {
        // ── 텍스트 글 ──
        // 실패해도 continue 하지 않음 — 기본 마커로 진행해 사진 마커 흐름 보호.
        try {
          if (textCardMode) {
            // 줌인 카드 (fromWidget). 17.5+ 는 클러스터링이 없어 바이트 불필요.
            icon = await _buildTextCardIcon(topPost);
            markerSize = _textCardSize;
            suppressCaption = true; // 카드에 제목/본문 포함 → 하단 캡션 중복 방지
          } else {
            // 줌아웃 점: 사진 마커와 동일한 바이트 파이프라인으로 생성.
            // → baseBytes 가 _markerBytesCache 에 저장되어 클러스터 +N 뱃지가
            //   사진 마커와 똑같이 자동 합성된다. markerSize 는 기본값(_normalMarkerSize).
            baseBytes = await _imageService.createTextDotImage();
            icon = await NOverlayImage.fromByteArray(baseBytes);
          }
        } catch (e) {
          debugPrint('[map] 텍스트 마커 생성 실패 ${topPost.id}: $e');
        }
        _textMarkerCardMode[topPost.id] = textCardMode;
      }

      visibleGroups.add([topPost]);

      // 클러스터 빌더에서 재사용할 캐시 저장.
      // 텍스트 마커는 icon 만 캐시(bytes 없음) → 텍스트가 top 인 클러스터의 +N 뱃지
      // 합성은 생략된다(원 글리프만 표시). 사진이 top 이면 기존대로 뱃지 합성됨.
      if (icon != null) {
        _markerIconCache[topPost.id] = icon;
      }
      if (baseBytes != null) {
        _markerBytesCache[topPost.id] = baseBytes;
      }

      final derivedTitle = displayTitle(topPost.title, topPost.content);
      final marker = NClusterableMarker(
        id: topPost.id,
        position: pos,
        icon: icon,
        size: markerSize,
        tags: {
          'score': topPost.score.toString(),
          // 클러스터 빌더가 tags 만 받으므로 유도 타이틀(타이틀 비면 본문 첫 줄)을
          // 여기서 계산해 담는다.
          'title': derivedTitle,
          // 클러스터 빌더에서 텍스트/이미지 구분 → 탭 시 줌 동작 분기.
          'isText': isTextPost ? '1' : '0',
        },
        caption: NOverlayCaption(
          // 카드 모드는 캡션 비움(카드에 제목 포함). 그 외엔 제목 캡션 표시.
          text: suppressCaption ? '' : _truncateMarkerTitle(derivedTitle),
          textSize: 13,
          color: captionTokens.textPrimary,
          haloColor: captionTokens.background,
        ),
      );

      final baseZIndex = 200000 + topPost.score.toInt();
      _markerRefs[topPost.id] = marker;
      _markerBaseZIndex[topPost.id] = baseZIndex;

      // setter는 모두 addOverlay 전에 호출 — _isAdded=false 가드로 native 호출은
      // 건너뛰고 값만 로컬에 저장된다. addOverlayAll 직렬화 시 함께 전송됨.
      marker.setGlobalZIndex(baseZIndex);

      final markerPostId = topPost.id;
      final bool markerIsText = isTextPost;
      final NLatLng markerPos = pos;
      marker.setOnTapListener((_) async {
        _focusNode.unfocus();
        // 텍스트 마커: 17.5 미만이면 카드가 펼쳐지도록 17.5로 줌인 후 종료.
        // (이미지 마커는 기존대로 줌 유지 + 선택)
        if (markerIsText) {
          final camera = await _mapController?.getCameraPosition();
          if (camera != null && camera.zoom < _textCardEnterZoom) {
            await _zoomToTextCard(markerPos);
            return;
          }
        }
        final idx = _postGroups
            .indexWhere((g) => g.isNotEmpty && g.first.id == markerPostId);
        if (idx < 0) return;
        await _selectMarker(idx);
      });

      markersToAdd.add(marker);
      markerIdsToAdd.add(topPost.id);
    }

    // 신규 마커들을 한 번에 native로 추가 (1회 reclustering).
    if (markersToAdd.isNotEmpty) {
      if (!mounted) return;
      final addStart = DateTime.now();
      debugPrint('[map] addOverlayAll start (${markersToAdd.length} markers)');
      await _mapController!.addOverlayAll(markersToAdd);
      debugPrint('[map] addOverlayAll done '
          '(${DateTime.now().difference(addStart).inMilliseconds}ms)');
      if (!mounted) return;
      _mapMarkerIds.addAll(markerIdsToAdd);
    } else {
      debugPrint('[map] addOverlayAll skipped (no new markers)');
    }

    if (!mounted) return;
    debugPrint('[map] setState visibleGroups=${visibleGroups.length}');
    setState(() {
      _postGroups = visibleGroups;
      // 이전 선택 마커가 새 결과에 있으면 그 인덱스로 유지, 없으면 카드 닫음
      if (prevSelectedPostId != null) {
        final newIdx = visibleGroups
            .indexWhere((g) => g.isNotEmpty && g.first.id == prevSelectedPostId);
        _selectedGroupIndex = newIdx >= 0 ? newIdx : null;
      } else if (_selectedGroupIndex != null &&
          _selectedGroupIndex! >= _postGroups.length) {
        _selectedGroupIndex = null;
      }
    });
    // 재조회로 마커 객체가 새로 생성된 경우에도 z-index 부스트 재적용
    if (_selectedGroupIndex != null) {
      _applySelectionHighlight(_postGroups[_selectedGroupIndex!].first.id);
    } else {
      _applySelectionHighlight(null);
    }
  }

  Future<void> _onSearch(String query) async {
    if (query.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    final results = await _searchService.search(query);
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  void _onResultTap(NaverLocalSearchResult result) {
    _focusNode.unfocus();
    setState(() {
      _searchResults = [];
      _selectedSymbol = null;
      _selectedPlace = result;
      _selectedGroupIndex = null;
    });
    _applySelectionHighlight(null);
    _searchController.text = result.title;

    final position = NLatLng(result.lat, result.lng);

    _mapController?.updateCamera(
      NCameraUpdate.scrollAndZoomTo(target: position, zoom: 16),
    );

    _addSearchMarker(result, position);
  }

  Future<void> _addSearchMarker(NaverLocalSearchResult result, NLatLng position) async {
    if (_mapController == null) return;

    if (_searchMarkerAdded) {
      _mapController!.deleteOverlay(NOverlayInfo(type: NOverlayType.marker, id: _searchMarkerId));
      _searchMarkerAdded = false;
    }

    final bytes = await _imageService.createPinMarkerImage();
    if (!mounted) return;
    final icon = await NOverlayImage.fromByteArray(bytes);

    final marker = NMarker(
      id: _searchMarkerId,
      position: position,
      icon: icon,
      size: const Size(32, 41),
      anchor: const NPoint(0.5, 1.0),
    );
    marker.setGlobalZIndex(1000000);

    _mapController!.addOverlay(marker);
    _searchMarkerAdded = true;
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _selectedPlace = null;
    });
    _focusNode.unfocus();
    if (_searchMarkerAdded && _mapController != null) {
      _mapController!.deleteOverlay(NOverlayInfo(type: NOverlayType.marker, id: _searchMarkerId));
      _searchMarkerAdded = false;
    }
  }

  Future<void> _onSymbolTapped(NSymbolInfo symbolInfo) async {
    _focusNode.unfocus();
    setState(() {
      _searchResults = [];
      _selectedGroupIndex = null;
      _selectedSymbol = symbolInfo;
      _selectedPlace = null;
      _isLoadingPlace = true;
    });
    _applySelectionHighlight(null);

    _mapController?.updateCamera(
      NCameraUpdate.scrollAndZoomTo(
        target: symbolInfo.position,
        zoom: 16,
      ),
    );

    final results = await _searchService.search(symbolInfo.caption);
    if (!mounted) return;
    setState(() {
      _selectedPlace = results.isNotEmpty ? results.first : null;
      _isLoadingPlace = false;
    });
  }

  Future<void> _onCameraIdle() async {
    if (_mapController == null) return;
    final camera = await _mapController!.getCameraPosition();
    final currentTarget = camera.target;
    final currentZoom = camera.zoom;
    debugPrint('[map] zoom=${currentZoom.toStringAsFixed(2)} '
        'target=(${currentTarget.latitude.toStringAsFixed(5)}, '
        '${currentTarget.longitude.toStringAsFixed(5)})');

    // 초기화 시점은 자동 호출 없이 기준값만 저장
    if (!_mapInitialized) {
      _mapInitialized = true;
      _lastQueriedTarget = currentTarget;
      _lastQueriedZoom = currentZoom;
      debugPrint('[map] cameraIdle baseline set (first call)');
      return;
    }

    // 변화량 임계값 — 줌 1단계 이상 OR 좌표 ~50m 이상
    final zoomChanged = (currentZoom - _lastQueriedZoom).abs() >= 1;
    bool positionChanged = false;
    if (_lastQueriedTarget != null) {
      final dLat = (currentTarget.latitude - _lastQueriedTarget!.latitude).abs();
      final dLng = (currentTarget.longitude - _lastQueriedTarget!.longitude).abs();
      positionChanged = dLat > 0.0005 || dLng > 0.0005;
    }
    // 텍스트 마커 점↔카드 모드가 실제로 바뀔 때만 재조회(히스테리시스 기반).
    // 경계에서 카메라가 미세하게 흔들려도 모드가 안 바뀌면 재조회하지 않아 깜빡임 제거.
    final modeFlipped = _peekTextCardMode(currentZoom) != _textCardMode;
    if (!zoomChanged && !positionChanged && !modeFlipped) {
      debugPrint('[map] cameraIdle below threshold → skip auto-reload');
      return;
    }

    // Debounce 500ms — 카메라 멈춘 시점에 1회 조회
    debugPrint('[map] cameraIdle changed (zoom=$zoomChanged pos=$positionChanged) '
        '→ schedule auto-reload in 500ms');
    _cameraDebounce?.cancel();
    _cameraDebounce = Timer(const Duration(milliseconds: 500), () {
      debugPrint('[map] cameraIdle debounce fired → auto _loadMapMarkers');
      _lastQueriedTarget = currentTarget;
      _lastQueriedZoom = currentZoom;
      _loadMapMarkers(
        currentTarget.latitude,
        currentTarget.longitude,
        currentZoom.round(),
        rawZoom: currentZoom,
      );
    });
  }

  String _truncateMarkerTitle(String title) =>
      title.length > 10 ? '${title.substring(0, 10)}...' : title;

  /// 텍스트 마커 표현(점↔카드)을 줌 히스테리시스로 결정하고 _textCardMode를 갱신.
  /// 카드 상태에서는 exit 미만으로 내려가야 점으로, 점 상태에서는 enter 이상이어야 카드로 전환.
  bool _resolveTextCardMode(double rawZoom) {
    if (_textCardMode) {
      if (rawZoom < _textCardExitZoom) _textCardMode = false;
    } else {
      if (rawZoom >= _textCardEnterZoom) _textCardMode = true;
    }
    return _textCardMode;
  }

  /// 상태를 바꾸지 않고 현재 줌에서의 모드만 예측 (onCameraIdle 재조회 판단용).
  bool _peekTextCardMode(double rawZoom) =>
      _textCardMode ? rawZoom >= _textCardExitZoom : rawZoom >= _textCardEnterZoom;

  void _closeAllCards() {
    if (_searchMarkerAdded && _mapController != null) {
      _mapController!.deleteOverlay(NOverlayInfo(type: NOverlayType.marker, id: _searchMarkerId));
      _searchMarkerAdded = false;
    }
    setState(() {
      _selectedSymbol = null;
      _selectedPlace = null;
      _isLoadingPlace = false;
      _selectedGroupIndex = null;
      _isCardExpanded = false;
      _cardDragOffset = 0.0;
    });
    _applySelectionHighlight(null);
  }

  /// 선택된 마커의 z-index를 다른 마커보다 위로 부스트.
  /// 아이콘은 그대로 유지 (사진 마커 유지).
  /// [markerId]가 null이면 부스트만 해제.
  /// idempotent: 재조회로 마커 객체가 새로 만들어진 케이스에도 안전하게 재적용됨.
  void _applySelectionHighlight(String? markerId) {
    final prevId = _highlightedMarkerId;
    if (prevId != null && prevId != markerId) {
      final prevMarker = _markerRefs[prevId];
      if (prevMarker != null) {
        final baseZ = _markerBaseZIndex[prevId];
        if (baseZ != null) {
          try {
            prevMarker.setGlobalZIndex(baseZ);
          } catch (_) {/* overlay가 이미 네이티브에서 제거된 경우 무시 */}
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
      }
    }
  }

  /// 텍스트 글 — 줌인 카드 아이콘. 꼬리 끝이 박스 하단 중앙(anchor 기본 0.5,1.0)에 오도록
  /// bottomCenter 정렬. 제목 없으면 본문만 카드.
  Future<NOverlayImage> _buildTextCardIcon(MapPost post) {
    final String? title =
        post.title.trim().isNotEmpty ? post.title.trim() : null;
    return NOverlayImage.fromWidget(
      context: context,
      size: _textCardSize,
      widget: SizedBox(
        width: _textCardSize.width,
        height: _textCardSize.height,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: TextMarkerCard(title: title, body: post.content, maxLines: 2),
        ),
      ),
    );
  }

  /// 텍스트 마커/클러스터 탭 시 카드가 펼쳐지도록 17.5로 줌인.
  Future<void> _zoomToTextCard(NLatLng target) async {
    if (_mapController == null) return;
    final update = NCameraUpdate.scrollAndZoomTo(
      target: target,
      zoom: _textCardCameraZoom,
    )..setAnimation(
        animation: NCameraAnimation.fly,
        duration: const Duration(milliseconds: 600),
      );
    await _mapController!.updateCamera(update);
  }

  /// 클러스터 마커 빌더.
  /// 아이콘 = score 최상위 마커 이미지 + 우상단 +N 뱃지(합성). caption = 타이틀(마커 아래).
  void _buildClusterMarker(NClusterInfo info, NClusterMarker clusterMarker) {
    debugPrint('[map] clusterBuilder called size=${info.size}');
    try {
    // children 중 score 최대 마커 식별
    String? topId;
    String? topTitle;
    NLatLng? topPosition;
    bool topIsText = false;
    double topScore = -1;
    for (final child in info.children) {
      final s = double.tryParse(child.tags['score'] ?? '0') ?? 0;
      if (s > topScore) {
        topScore = s;
        topId = child.id;
        topTitle = child.tags['title'];
        topPosition = child.position;
        topIsText = child.tags['isText'] == '1';
      }
    }

    if (topId != null) {
      // 현재 빌드 시점의 size 기록 → 비동기 합성 결과의 stale 적용 방지
      _clusterCurrentSize[topId] = info.size;

      if (info.size == 1) {
        // 단일 마커가 클러스터 빌더 거치는 경우 — 일반 마커처럼 표시 (사이즈 + 뱃지 없음)
        final base = _markerIconCache[topId];
        if (base != null) {
          clusterMarker.setIcon(base);
          clusterMarker.setSize(const Size(_normalMarkerSize, _normalMarkerSize));
        }
      } else {
        final cacheKey = '${topId}_${info.size}';
        final composed = _clusterIconCache[cacheKey];
        if (composed != null) {
          // 합성 캐시 있음 → 즉시 적용
          clusterMarker.setIcon(composed);
          clusterMarker.setSize(const Size(_clusterMarkerSize, _clusterMarkerSize));
        } else {
          // 합성 캐시 없음 → 일단 base icon 사용 (즉시 표시), 비동기로 합성 후 교체
          final base = _markerIconCache[topId];
          if (base != null) {
            clusterMarker.setIcon(base);
            clusterMarker.setSize(const Size(_clusterMarkerSize, _clusterMarkerSize));
          }
          _composeClusterIconAsync(topId, info.size, clusterMarker);
        }
      }
    }

    // 마커 아래 타이틀 (일반 마커와 동일)
    final title = (topTitle ?? '').trim();
    clusterMarker.setCaption(NOverlayCaption(
      text: title.isEmpty ? '' : _truncateMarkerTitle(title),
      textSize: 13,
      color: AppColors.of(context).textPrimary,
      haloColor: AppColors.of(context).background,
    ));
    clusterMarker.setCaptionAligns(const [NAlign.bottom]);
    clusterMarker.setCaptionOffset(0);

    // 단일 마커(size==1)가 클러스터 빌더를 통과할 때 — 줌 15에서 클러스터링이
    // 활성이므로 NClusterableMarker 자체의 tap listener가 발동되지 않는다.
    // NClusterMarker에 직접 listener를 달아 선택 흐름으로 전달.
    if (info.size == 1 && topId != null) {
      final singleId = topId;
      final bool isTxt = topIsText;
      final NLatLng? tpos = topPosition;
      clusterMarker.setOnTapListener((_) async {
        _focusNode.unfocus();
        // 텍스트 단일 마커: 17.5 미만이면 17.5로 줌인(카드). 이미지는 기존대로 선택.
        if (isTxt && tpos != null) {
          final camera = await _mapController?.getCameraPosition();
          if (camera != null && camera.zoom < _textCardEnterZoom) {
            await _zoomToTextCard(tpos);
            return;
          }
        }
        final idx = _postGroups
            .indexWhere((g) => g.isNotEmpty && g.first.id == singleId);
        if (idx < 0) return;
        _selectMarker(idx);
      });
    }

    // 클러스터(size>1) 탭 → 줌 16+ 자동 확대. 줌 16부터 클러스터링이 비활성
    // 이므로 자연스럽게 풀리며, 사용자가 펼쳐진 jitter 마커를 한 번 더 탭해서
    // 카드/스트립으로 진입.
    if (info.size > 1 && topPosition != null) {
      final target = topPosition;
      final bool isTxt = topIsText;
      clusterMarker.setOnTapListener((_) async {
        if (_mapController == null) return;
        _focusNode.unfocus();
        final camera = await _mapController!.getCameraPosition();
        // 텍스트 클러스터 → 17.5(카드). 이미지 클러스터 → 기존(16+ 확대) 유지.
        final nextZoom = isTxt
            ? _textCardCameraZoom
            : (camera.zoom < 16 ? 16.0 : camera.zoom);
        final update = NCameraUpdate.scrollAndZoomTo(
          target: target,
          zoom: nextZoom,
        )..setAnimation(
            animation: NCameraAnimation.fly,
            duration: const Duration(milliseconds: 600),
          );
        await _mapController!.updateCamera(update);
      });
    }
    } catch (_) {}
  }

  /// 클러스터 뱃지가 합성된 아이콘을 비동기로 만들어 캐시에 저장하고 마커에 적용.
  /// 클러스터링 incremental 호출(size 1→2→3..) 동안 카운트업 잔상을 피하려고
  /// 합성 후 짧게 기다린 뒤 그 시점의 최종 size일 때만 setIcon 적용.
  Future<void> _composeClusterIconAsync(
      String topId, int size, NClusterMarker clusterMarker) async {
    final baseBytes = _markerBytesCache[topId];
    if (baseBytes == null) {
      debugPrint('[map] composeCluster skip (no baseBytes) topId=$topId size=$size');
      return;
    }
    debugPrint('[map] composeCluster start topId=$topId size=$size');
    try {
      final composedBytes = await _imageService.addClusterBadge(baseBytes, size);
      final composedIcon = await NOverlayImage.fromByteArray(composedBytes);
      if (!mounted) return;
      _clusterIconCache['${topId}_$size'] = composedIcon;

      // 클러스터링 안정 대기 — 그 사이 같은 topId의 더 큰 size가 도착하면 stale 처리
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      if (_clusterCurrentSize[topId] != size) {
        debugPrint('[map] composeCluster stale topId=$topId size=$size '
            'now=${_clusterCurrentSize[topId]}');
        return; // 이미 다른 size로 변경됨
      }
      // delay 사이 native에서 클러스터가 사라졌을 수 있음 — isAdded로 한 번 더 검증.
      if (!clusterMarker.isAdded) {
        debugPrint('[map] composeCluster notAdded topId=$topId size=$size');
        return;
      }

      // isAdded 체크 후 setIcon/setSize 사이에 native에서 클러스터가 제거된
      // 잔여 윈도우 보호 (Android 한정 race; iOS는 native가 빨라 무증상).
      try {
        clusterMarker.setIcon(composedIcon);
        clusterMarker.setSize(const Size(_clusterMarkerSize, _clusterMarkerSize));
        debugPrint('[map] composeCluster applied topId=$topId size=$size');
      } catch (e) {
        debugPrint('[map] composeCluster setIcon caught: $e');
      }
    } catch (e) {
      debugPrint('[map] composeCluster outer caught: $e');
    }
  }

  /// 마커가 화면 세로 22% 지점, 가로 중앙에 보이도록 카메라 이동 (fly 600ms).
  /// [zoom] 지정 시 줌도 함께 변경되며, 한 번의 애니메이션으로 처리됨.
  /// 알고리즘: 카메라 target을 (markerPos + (cameraTarget - desiredCoord))로 두면
  /// 새 카메라에서 markerPos가 원하는 픽셀에 정확히 매핑됨. 줌이 바뀌면 lat/lng 오프셋을
  /// 2^(currentZoom - targetZoom) 비율로 스케일해야 픽셀 위치가 맞음.
  Future<void> _moveCameraToMarker(NLatLng markerPos, {double? zoom}) async {
    if (_mapController == null) return;
    final size = MediaQuery.sizeOf(context);

    final camera = await _mapController!.getCameraPosition();
    final currentZoom = camera.zoom;
    final targetZoom = zoom ?? currentZoom;
    final cameraTarget = camera.target;

    final desiredPixel = NPoint(size.width / 2, size.height * 0.22);
    final desiredCoord =
        await _mapController!.screenLocationToLatLng(desiredPixel);

    var dLat = cameraTarget.latitude - desiredCoord.latitude;
    var dLng = cameraTarget.longitude - desiredCoord.longitude;

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
    _lastQueriedTarget = adjustedTarget;
    // 줌도 함께 기준값으로 갱신 — 카드 넘김 시 idle에서 불필요한 재조회가 도는 것 방지.
    _lastQueriedZoom = targetZoom;
    await _mapController!.updateCamera(update);
  }

  /// 주어진 인덱스의 마커를 선택: 카메라 이동(필요시 줌16) + z-index 부스트 + 스트립 위치 갱신.
  /// 마커 탭, 스트립 탭, 카드 좌우 스와이프 등 모든 그룹 전환 경로의 공통 진입점.
  Future<void> _selectMarker(int idx) async {
    if (idx < 0 || idx >= _postGroups.length) return;
    if (_mapController == null) return;
    final post = _postGroups[idx].first;
    final markerPos = _markerRefs[post.id]?.position
        ?? NLatLng(post.latitude, post.longitude);

    final camera = await _mapController!.getCameraPosition();
    final targetZoom = camera.zoom < 16 ? 16.0 : camera.zoom;

    setState(() {
      _searchResults = [];
      _selectedSymbol = null;
      _selectedPlace = null;
      _isLoadingPlace = false;
      _selectedGroupIndex = idx;
    });
    _applySelectionHighlight(post.id);
    await _moveCameraToMarker(markerPos, zoom: targetZoom);
  }

  void _onCardDragUpdate(DragUpdateDetails details) {
    if (details.delta.dy > 0) {
      setState(() => _cardDragOffset += details.delta.dy);
    }
  }

  void _onCardDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_cardDragOffset > _dismissThreshold || velocity > 400) {
      _closeAllCards();
    } else {
      setState(() => _cardDragOffset = 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    const seoulCityHall = NLatLng(37.5666, 126.979);
    final safeAreaPadding = MediaQuery.paddingOf(context);
    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return Scaffold(
      body: Stack(
        children: [
          NaverMap(
            options: NaverMapViewOptions(
              contentPadding: safeAreaPadding,
              initialCameraPosition: NCameraPosition(target: seoulCityHall, zoom: 15),
              consumeSymbolTapEvents: true,
              minZoom: 10,
              maxZoom: 20,
              // 다크모드일 때만 navi 타입 + 야간 모드 (라이브러리 한계: nightMode는 navi 전용)
              mapType: isDark ? NMapType.navi : NMapType.basic,
              nightModeEnable: isDark,
            ),
            clusterOptions: NaverMapClusteringOptions(
              // 줌 15까지 클러스터링, 16+ 부터는 모든 마커 펼침.
              // 기본 진입 줌(15)에서도 가까운 사진 마커를 묶어 밀집 지역의
              // 시각적 혼잡을 줄인다.
              enableZoomRange: const NInclusiveRange(0, 15),
              // 0으로 두어 size 1→2→3 점진 증가하는 카운트업 잔상 제거
              animationDuration: Duration.zero,
              mergeStrategy: const NClusterMergeStrategy(
                willMergedScreenDistance: {
                  // 줌 10-12 (시·도): 100dp 이내 마커 묶음 (넓게)
                  NInclusiveRange(10, 12): 100.0,
                  // 줌 13-14 (구·동): 85dp (동네 단위 정리)
                  NInclusiveRange(13, 14): 85.0,
                  // 줌 15 (기본 진입): 가까운 마커만 60dp 이내로 묶음
                  NInclusiveRange(15, 15): 60.0,
                },
              ),
              clusterMarkerBuilder: _buildClusterMarker,
            ),
            onMapReady: (controller) {
              setState(() => _mapController = controller);
              _moveToCurrentLocationOrDefault();
            },
            onMapTapped: (point, latLng) {
              _focusNode.unfocus();
              _closeAllCards();
            },
            onSymbolTapped: _onSymbolTapped,
            onCameraIdle: _onCameraIdle,
          ),
          // 검색창 — 카드 열려있으면 페이드아웃 + 터치 비활성
          Positioned(
            top: safeAreaPadding.top + 12,
            left: 25,
            right: 25,
            child: IgnorePointer(
              ignoring: _isAnyCardOpen,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _isAnyCardOpen ? 0 : 1,
                child: Column(
              children: [
                Container(
                  key: _searchBarKey,
                  decoration: BoxDecoration(
                    color: AppColors.of(context).surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.of(context).shadow,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    onSubmitted: (v) {
                      _debounce?.cancel();
                      _onSearch(v);
                    },
                    textInputAction: TextInputAction.search,
                    style: TextStyle(
                      fontSize: 15,
                      fontFamily: 'Pretendard',
                      color: AppColors.of(context).textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: '장소 검색',
                      hintStyle: TextStyle(
                        color: AppColors.of(context).textMuted,
                        fontFamily: 'Pretendard',
                      ),
                      prefixIcon: _isSearching
                          ? Padding(
                              padding: const EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.of(context).primaryStrong,
                                ),
                              ),
                            )
                          : Icon(Icons.search, color: AppColors.of(context).textMuted),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close, color: AppColors.of(context).textMuted, size: 20),
                              onPressed: _clearSearch,
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onChanged: (v) {
                      setState(() {});
                      _debounce?.cancel();
                      if (v.trim().length < 2) {
                        setState(() => _searchResults = []);
                        return;
                      }
                      _debounce = Timer(const Duration(milliseconds: 300), () {
                        _onSearch(v);
                      });
                    },
                  ),
                ),
                // 검색 결과 목록
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: AppColors.of(context).surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.of(context).shadow,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return ListTile(
                          dense: true,
                          leading: Icon(Icons.place_outlined, color: AppColors.of(context).primaryStrong, size: 20),
                          title: Text(
                            result.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w600,
                              color: AppColors.of(context).textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            result.roadAddress.isNotEmpty ? result.roadAddress : result.address,
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'Pretendard',
                              color: AppColors.of(context).textMuted,
                            ),
                          ),
                          onTap: () => _onResultTap(result),
                        );
                      },
                    ),
                  ),
              ],
            ),
              ),
            ),
          ),
          // 내 위치 버튼 — 좌측 하단 고정
          Positioned(
            left: 16,
            bottom: 45,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: NMyLocationButtonWidget(
                key: ValueKey(_isAnyCardOpen),
                mapController: _mapController,
                size: 40,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          // POI 심볼 탭 시 하단 장소 카드
          AnimatedPositioned(
            duration: _cardDragOffset > 0
                ? Duration.zero
                : const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            left: 0,
            right: 0,
            bottom: (_selectedSymbol != null || _selectedPlace != null) ? -_cardDragOffset : -200,
            child: _PlaceInfoCard(
              symbol: _selectedSymbol,
              place: _selectedPlace,
              isLoading: _isLoadingPlace,
              safeAreaBottom: safeAreaPadding.bottom,
              onClose: _closeAllCards,
              onDragUpdate: _onCardDragUpdate,
              onDragEnd: _onCardDragEnd,
            ),
          ),
          // 마커 탭 시 바텀시트 카드 — 등장/소실 시 슬라이드 + 페이드
          // 확장 상태일 때는 네비게이션 바에 바로 붙도록 bottom: 0
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            bottom: _isCardExpanded ? 0 : 20,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              reverseDuration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final slide = Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(animation);
                return SlideTransition(
                  position: slide,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              layoutBuilder: (currentChild, previousChildren) => Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              ),
              child: _selectedGroupIndex != null
                  ? MapBottomCard(
                      key: const ValueKey('card'),
                      groups: _postGroups,
                      initialGroupIndex: _selectedGroupIndex!,
                      minTopMargin: _searchBarBottom > 0
                          ? _searchBarBottom + 30
                          : MediaQuery.paddingOf(context).top + 80,
                      onClose: () {
                        setState(() {
                          _selectedGroupIndex = null;
                          _isCardExpanded = false;
                        });
                        _applySelectionHighlight(null);
                      },
                      onGroupChanged: (newIdx) {
                        _selectMarker(newIdx);
                      },
                      onExpandedChanged: (expanded) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _isCardExpanded = expanded);
                        });
                      },
                      onPostEdited: () {
                        // 내 글 수정/삭제 반영 — 카드 닫고 마커 새로고침.
                        _closeAllCards();
                        refreshMap();
                      },
                    )
                  : const SizedBox.shrink(key: ValueKey('empty')),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceInfoCard extends StatelessWidget {
  final NSymbolInfo? symbol;
  final NaverLocalSearchResult? place;
  final bool isLoading;
  final double safeAreaBottom;
  final VoidCallback onClose;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;

  const _PlaceInfoCard({
    required this.symbol,
    required this.place,
    required this.isLoading,
    required this.safeAreaBottom,
    required this.onClose,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final name = place?.title ?? symbol?.caption ?? '';
    final address = place != null
        ? (place!.roadAddress.isNotEmpty ? place!.roadAddress : place!.address)
        : '';

    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + safeAreaBottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onVerticalDragUpdate: onDragUpdate,
            onVerticalDragEnd: onDragEnd,
            behavior: HitTestBehavior.translucent,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.place, color: colors.primaryStrong, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: isLoading
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            symbol?.caption ?? '',
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.primaryStrong,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 16,
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          if (address.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              address,
                              style: TextStyle(
                                fontSize: 13,
                                fontFamily: 'Pretendard',
                                color: colors.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
              IconButton(
                onPressed: onClose,
                icon: Icon(Icons.close, color: colors.textMuted, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

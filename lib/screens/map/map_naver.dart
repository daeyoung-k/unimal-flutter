import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:unimal/screens/map/bottom_card/map_bottom_card.dart';
import 'package:unimal/screens/map/marker/marker_constants.dart';
import 'package:unimal/screens/map/marker/marker_score_tiers.dart';
import 'package:unimal/screens/map/marker/text_marker_widgets.dart';
import 'package:unimal/service/board/board_api_service.dart';
import 'package:unimal/screens/map/marker/marker_image_factory.dart';
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
  final MarkerImageFactory _markerImageFactory = MarkerImageFactory();
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
  // 마커 ID → 기본 표시 크기(dp). score 위계(42/50/58/66)로 결정되며
  // 선택 확대(x1.18)와 선택 해제 복원의 기준값.
  final Map<String, double> _markerBaseSize = {};
  // 마커 ID → 같은 자리 스택 글 수. 1이면 단일, 2+면 스택(+N 뱃지).
  // 재조회 시 글 수가 바뀌면 아이콘 재합성 판단에 사용.
  final Map<String, int> _markerStackCount = {};
  // 마커 ID → 핫플(캡션 우선권) 여부. 뷰포트 이동으로 백분위가 바뀌면
  // 재사용 마커에도 setIsForceShowCaption 을 갱신하기 위해 추적.
  final Map<String, bool> _markerIsHot = {};

  // ── 스택 원형 펼침 (B안) 상태 ──────────────────────────────────────────
  // 현재 펼쳐진 스택 마커 id (대표 게시글 id). null 이면 접힘.
  String? _expandedStackId;
  // 펼침 구성 오버레이 id — 접을 때 제거용.
  final List<String> _stackFanMarkerIds = [];
  final List<String> _stackFanLegIds = [];
  bool _stackFanCenterAdded = false;
  // 펼침 직후 카메라 기준값 — 여기서 벗어나면(지도 이동) 자동으로 접는다.
  NLatLng? _stackFanBaseTarget;
  double? _stackFanBaseZoom;
  // 펼침 호출 시퀀스 — 연속 호출 경합 시 이전 호출 무효화.
  int _stackFanSeq = 0;
  // 글 id → 펼침 마커 위치. 카드 스와이프 시 카메라 팔로우용.
  final Map<String, NLatLng> _stackFanPositions = {};
  // 마지막으로 카메라를 보낸 펼침 글 id — 탭/스와이프 에코 중복 이동 방지.
  String? _stackFanFocusedPostId;
  // 펼침 마커 z-index — 일반 마커(200000+score)와 선택(999999999) 사이.
  static const int _stackFanZIndex = 900000000;
  static const String _stackFanCenterId = 'stack_fan_center';
  static const String _stackFanCenterHaloId = 'stack_fan_center_halo';
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
  // 그룹 내 특정 글 페이지 강제 (스택 펼침 마커 탭). null = 강제 없음.
  int? _selectedPostIndex;
  bool _isCardExpanded = false;
  List<MapPost> get _selectedPosts =>
      _selectedGroupIndex == null ? const [] : _postGroups[_selectedGroupIndex!];

  // 카드 드래그 관련 상태
  double _cardDragOffset = 0.0;

  // 주변 스토리 조회 버튼 관련 상태
  bool _mapInitialized = false;
  NLatLng? _lastQueriedTarget;
  double _lastQueriedZoom = _defaultEntryZoom;

  // 카메라 이동 자동 조회 — debounce + lock
  Timer? _cameraDebounce;
  bool _isLoadingMarkers = false;
  // refreshMap() 호출 시 로드가 진행 중이면 완료 후 강제 새로고침을 실행하기 위한 플래그
  bool _pendingForceRefresh = false;

  Worker? _pendingLocationWorker;

  static const _searchMarkerId = 'search_result_marker';
  static const _dismissThreshold = 80.0;
  bool _searchMarkerAdded = false;

  // 마커 크기·캡션 — marker_constants.dart 공용 값 (내지도와 반드시 동일).
  static const _normalMarkerSize = kNormalMarkerSize; // 일반(단일) 마커
  static const _clusterMarkerSize = kClusterMarkerSize; // 클러스터 마커
  static const double _markerCaptionTextSize = kMarkerCaptionTextSize;
  // 텍스트 카드 크기/줌 — marker_constants.dart 공용 값 (내지도와 동일).
  static const Size _textCardSize = kTextCardSize;
  static const double _textCardCameraZoom = kTextCardCameraZoom;
  static const double _textCardEnterZoom = kTextCardEnterZoom;
  static const double _textCardExitZoom = kTextCardExitZoom;
  // 이미지 클러스터 탭 시 줌인 목표 — 공용 상수 (내지도와 동일).
  // 단일 마커 선택(_selectMarker), 다른 화면발 위치 이동(_applyPendingLocation)도
  // 같은 깊이로 통일.
  static const double _clusterExpandZoom = kClusterExpandZoom;
  // 장소(검색 결과·POI 심볼) 포커스 줌 — 스토리 마커가 아닌 장소 확인용이라
  // 마커 선택보다 얕게 유지.
  static const double _placeFocusZoom = 16.0;
  // 기본 진입 줌. 14로 낮춰봤으나 넓은 범위가 들어오며 먼 마커끼리
  // 클러스터로 묶여 보이는 문제가 있어 15로 유지 — 병합 거리 축소(40dp)와
  // 조합해 "가까운 것만 묶임"이 되도록 한다.
  static const double _defaultEntryZoom = 16.5;

  bool get _isAnyCardOpen => _selectedSymbol != null || _selectedPosts.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pendingLocationWorker = ever(
      Get.find<NavController>().pendingMapLat,
      (_) => _applyPendingLocation(),
    );
  }

  // 검색바 우측 '내 지도' 진입 버튼.
  // 지도 핀 아이콘 + '내 지도' 텍스트 알약 — 무엇을 누르는지 글자로 명확히 보여준다.
  // 탭 시 나만의 지도(owner)로 이동.
  Widget _buildMyMapButton() {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: () => Get.toNamed('/my-story-map'),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
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
            Icon(Icons.place, size: 16, color: colors.primaryStrong),
            const SizedBox(width: 4),
            Text(
              '내 지도',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFamily: 'Pretendard',
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
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
    _markerBaseSize.clear();
    _markerStackCount.clear();
    _markerIsHot.clear();
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
        '${lng.toStringAsFixed(5)}) zoom=$_clusterExpandZoom');
    if (_mapController != null) {
      _mapController!.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
            target: NLatLng(lat, lng), zoom: _clusterExpandZoom),
      );
      _loadMapMarkers(lat, lng, _clusterExpandZoom.round());
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
    _markerBaseSize.clear();
    _markerStackCount.clear();
    _markerIsHot.clear();
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
            '${position.longitude.toStringAsFixed(5)}) zoom=$_defaultEntryZoom');
        _mapController?.updateCamera(
          NCameraUpdate.scrollAndZoomTo(
            target: NLatLng(position.latitude, position.longitude),
            zoom: _defaultEntryZoom,
          ),
        );
        _loadMapMarkers(
            position.latitude, position.longitude, _defaultEntryZoom.round());
      } else {
        debugPrint('[map] fallback → seoulCityHall');
        _loadMapMarkers(seoulCityHall.latitude, seoulCityHall.longitude,
            _defaultEntryZoom.round());
      }
    } catch (e) {
      debugPrint('[map] _moveToCurrentLocationOrDefault outer catch: $e → fallback');
      if (mounted) {
        _loadMapMarkers(seoulCityHall.latitude, seoulCityHall.longitude,
            _defaultEntryZoom.round());
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

    // 같은 자리끼리 그룹핑 — 스택 마커(A안)의 단위.
    // jitter 로 흩뿌리던 방식을 폐기하고 그룹당 마커 하나(대표 + 뒷장 + +N 뱃지)로
    // 쌓는다. 줌인해도 유지되며, 탭하면 하단 카드 스트립에서 그룹 내 글을 넘겨본다.
    // 정밀도 주의: kStackGroupPrecision(4자리 ≈ 11m) — 진짜 같은 지점만 묶는다.
    final Map<String, List<MapPost>> grouped = {};
    for (final post in posts) {
      final key =
          '${post.latitude.toStringAsFixed(kStackGroupPrecision)},'
          '${post.longitude.toStringAsFixed(kStackGroupPrecision)}';
      grouped.putIfAbsent(key, () => []).add(post);
    }
    // 그룹 내 score 내림차순 — 첫 글이 대표(마커 아이콘·캡션·zIndex 기준)
    for (final list in grouped.values) {
      list.sort((a, b) => b.score.compareTo(a.score));
    }

    final List<List<MapPost>> markerGroups = grouped.values.toList();

    // score 크기 위계 — 화면에 로드된 마커(그룹 대표 score)의 상대 백분위.
    final tiers =
        MarkerScoreTiers.fromScores(markerGroups.map((g) => g.first.score));

    // 밀집 지역 판정(C안) — 주변에 다른 마커 그룹이 몰려 있으면
    // 텍스트 마커를 줌인해도 카드로 펼치지 않고 점으로 고정.
    bool isDenseGroup(MapPost top) {
      int neighbors = 0;
      for (final other in markerGroups) {
        final o = other.first;
        if (identical(o, top)) continue;
        if ((o.latitude - top.latitude).abs() < kTextCardDenseRadiusDeg &&
            (o.longitude - top.longitude).abs() < kTextCardDenseRadiusDeg) {
          neighbors++;
          if (neighbors >= kTextCardDenseNeighbors) return true;
        }
      }
      return false;
    }

    // 새 결과의 마커 ID 집합 (그룹 대표 게시글 id 1:1)
    final newMarkerIds = markerGroups.map((g) => g.first.id).toSet();
    debugPrint('[map] markerGroups built: ${markerGroups.length} markers '
        '(grouped from ${posts.length} posts, tiers=${tiers.enabled})');

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
        _markerBaseSize.remove(id);
        _markerStackCount.remove(id);
        _markerIsHot.remove(id);
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

    // 2) 그룹(스택)마다 마커 하나 + visibleGroup(그룹 전체) 추가
    final List<List<MapPost>> visibleGroups = [];
    // 신규 마커는 한 번에 addOverlayAll로 추가한다.
    // 한 개씩 addOverlay 하면 native가 매 호출마다 reclustering(release→retain)을
    // 수행하면서 빌더 이벤트가 N번 발생하고, 이전 이벤트에서 시작된
    // lSyncClusterMarker가 도착할 때 해당 클러스터가 이미 release되어
    // "overlay can't found" race 가 일어남 (Android 한정).
    // addOverlayAll은 native에서 1번의 reclustering으로 마무리되어 race 윈도우 제거.
    final Set<NClusterableMarker> markersToAdd = {};
    final List<String> markerIdsToAdd = [];

    // 텍스트 점↔카드 전환은 화면 단위 줌 히스테리시스 — 루프 밖에서 1회 결정.
    // (경계 줌에서 카메라가 미세하게 흔들려도 점↔카드가 깜빡이지 않게)
    final bool globalTextCardMode =
        _resolveTextCardMode(rawZoom ?? zoom.toDouble());

    for (final group in markerGroups) {
      final topPost = group.first;
      final pos = NLatLng(topPost.latitude, topPost.longitude);
      final int stackCount = group.length;

      final bool isTextPost = topPost.fileInfoList.isEmpty;
      // 텍스트 카드가 될 수 있는 조건: 단일 글 + 밀집 아님(C안).
      // 스택(2+)과 밀집 지역은 줌인해도 점 유지 — 글은 하단 스트립에서 읽는다.
      final bool canBecomeCard =
          isTextPost && stackCount == 1 && !isDenseGroup(topPost);
      final bool textCardMode = canBecomeCard && globalTextCardMode;

      // score 크기 위계 (42/50/58/66) — 그룹 대표 score 의 화면 내 백분위.
      final double tierSize = tiers.sizeFor(topPost.score);
      final bool isHot = tiers.isHot(topPost.score);

      // 이미 화면에 있는 마커 → 재사용.
      // 단, 텍스트 점↔카드 모드가 바뀌었거나 스택 글 수가 바뀌면 재생성.
      if (_mapMarkerIds.contains(topPost.id)) {
        final bool needsRebuild =
            (isTextPost && _textMarkerCardMode[topPost.id] != textCardMode) ||
                _markerStackCount[topPost.id] != stackCount;
        if (!needsRebuild) {
          // 위계 변화(뷰포트 이동으로 백분위가 바뀜)는 재합성 없이 반영:
          // 크기는 setSize, 캡션 우선권은 setIsForceShowCaption.
          // 카드 모드(가변 크기)와 선택 중 마커의 크기는 제외.
          final bool cardSized = isTextPost && textCardMode;
          if (!cardSized && _markerBaseSize[topPost.id] != tierSize) {
            _markerBaseSize[topPost.id] = tierSize;
            if (_highlightedMarkerId != topPost.id) {
              try {
                _markerRefs[topPost.id]?.setSize(Size(tierSize, tierSize));
              } catch (_) {/* 네이티브에서 이미 제거된 경우 무시 */}
            }
          }
          if (_markerIsHot[topPost.id] != isHot) {
            _markerIsHot[topPost.id] = isHot;
            try {
              _markerRefs[topPost.id]?.setIsForceShowCaption(isHot);
            } catch (_) {/* same */}
          }
          visibleGroups.add(group);
          continue;
        }
        // 재생성 필요 → 제거하고 fall-through
        try {
          _mapController!.deleteOverlay(
            NOverlayInfo(type: NOverlayType.clusterableMarker, id: topPost.id),
          );
        } catch (_) {}
        _mapMarkerIds.remove(topPost.id);
        _markerIconCache.remove(topPost.id);
        _markerBytesCache.remove(topPost.id);
        // 이전 base 로 합성된 클러스터 아이콘도 무효화 (stale 뱃지 방지)
        _clusterIconCache
            .removeWhere((key, _) => key.startsWith('${topPost.id}_'));
        _markerRefs.remove(topPost.id);
        _markerBaseZIndex.remove(topPost.id);
        _markerBaseSize.remove(topPost.id);
        _markerStackCount.remove(topPost.id);
        _markerIsHot.remove(topPost.id);
      }

      // 신규(또는 재생성) 마커 생성
      NOverlayImage? icon;
      Uint8List? baseBytes;
      Size markerSize = Size(tierSize, tierSize);
      bool suppressCaption = false;

      if (!isTextPost) {
        // ── 사진 글: 원형 썸네일 + 링 (내 글=primary, 새 글 24h=accent) ──
        try {
          final firstUrl = topPost.fileInfoList.first.fileUrl;
          final stream = await _markerImageFactory.getImageStream(firstUrl);
          baseBytes = await _markerImageFactory.createMarkerImage(
            stream,
            ringColor: markerRingColor(
              isOwner: topPost.isOwner,
              createdAt: topPost.createdAt,
            ),
          );
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
            // → baseBytes 가 _markerBytesCache 에 저장되어 클러스터/스택 +N 뱃지가
            //   사진 마커와 똑같이 합성된다.
            baseBytes = await _markerImageFactory.createTextDotImage();
          }
        } catch (e) {
          debugPrint('[map] 텍스트 마커 생성 실패 ${topPost.id}: $e');
        }
        _textMarkerCardMode[topPost.id] = textCardMode;
      }

      // 같은 자리 스택(A안): 대표 마커 뒤 뒷장 + 우상단 +N 뱃지 합성.
      // _markerBytesCache 에는 합성 전 base 를 남겨 클러스터 뱃지 합성과 호환.
      if (baseBytes != null) {
        try {
          final displayBytes = stackCount > 1
              ? await _markerImageFactory.composeStackMarker(
                  baseBytes, stackCount)
              : baseBytes;
          icon = await overlayImageFromBytes(displayBytes);
        } catch (e) {
          if (!isTextPost) continue; // 사진 글은 아이콘 없이 진행 불가
          debugPrint('[map] 텍스트 마커 아이콘 생성 실패 ${topPost.id}: $e');
        }
      }

      visibleGroups.add(group);

      // 클러스터 빌더에서 재사용할 캐시 저장.
      // 텍스트 카드 마커는 icon 만 캐시(bytes 없음) → 텍스트가 top 인 클러스터의
      // +N 뱃지 합성은 생략된다(글리프만 표시). 그 외에는 뱃지 합성됨.
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
          // 카드로 펼쳐질 수 있는 텍스트 마커인지 (단일 + 비밀집).
          // 클러스터 빌더의 단일 마커 탭 시 카드 줌 유도 여부 분기에 사용.
          // 스택/밀집 텍스트는 줌인해도 점이라 카드 줌 유도가 무의미하다.
          'canCard': canBecomeCard ? '1' : '0',
          // 스택 글 수 — 클러스터 +N 뱃지가 마커 수가 아닌 글 수 합계를 표시.
          'count': stackCount.toString(),
        },
        caption: NOverlayCaption(
          // 카드 모드는 캡션 비움(카드에 제목 포함). 그 외엔 제목 캡션 표시.
          text: suppressCaption ? '' : _truncateMarkerTitle(derivedTitle),
          textSize: _markerCaptionTextSize,
          color: captionTokens.textPrimary,
          haloColor: captionTokens.background,
        ),
      );

      final baseZIndex = 200000 + topPost.score.toInt();
      _markerRefs[topPost.id] = marker;
      _markerBaseZIndex[topPost.id] = baseZIndex;
      _markerBaseSize[topPost.id] = tierSize;
      _markerStackCount[topPost.id] = stackCount;
      _markerIsHot[topPost.id] = isHot;

      // setter는 모두 addOverlay 전에 호출 — _isAdded=false 가드로 native 호출은
      // 건너뛰고 값만 로컬에 저장된다. addOverlayAll 직렬화 시 함께 전송됨.
      marker.setGlobalZIndex(baseZIndex);
      // 캡션 우선권 — 마커가 겹치면 zIndex(=score) 낮은 쪽 캡션을 숨긴다.
      // 핫플(상위 5%)은 어떤 충돌 상황에도 캡션 유지 (피그마 §2).
      marker.setIsHideCollidedCaptions(true);
      if (isHot) marker.setIsForceShowCaption(true);
      // 원형 펼침 중인 스택이 재조회로 재생성되는 경우 숨김 상태 유지.
      if (topPost.id == _expandedStackId) marker.setIsVisible(false);

      final markerPostId = topPost.id;
      final bool markerCanBecomeCard = canBecomeCard;
      final bool markerIsStack = stackCount > 1;
      marker.setOnTapListener((_) async {
        _focusNode.unfocus();
        // 스택(같은 자리 2+ 글) 탭 → 원형 펼침 (B안). 카드는 펼쳐진
        // 개별 마커를 탭했을 때 연다.
        if (markerIsStack) {
          await _expandStackFan(markerPostId);
          return;
        }
        // 단일 마커는 어느 줌에서 탭하든 줌인 + 카메라 무빙 + 카드 오픈을
        // 한 번에 (기존 "줌인만 하고 종료"는 탭이 씹힌 느낌 — 2026-07-13).
        // 텍스트 카드 마커는 카드 표시 줌(19)까지 당긴다.
        final idx = _postGroups
            .indexWhere((g) => g.isNotEmpty && g.first.id == markerPostId);
        if (idx < 0) return;
        await _selectMarker(
          idx,
          minZoom: markerCanBecomeCard ? _textCardCameraZoom : null,
        );
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
      NCameraUpdate.scrollAndZoomTo(target: position, zoom: _placeFocusZoom),
    );

    _addSearchMarker(result, position);
  }

  Future<void> _addSearchMarker(NaverLocalSearchResult result, NLatLng position) async {
    if (_mapController == null) return;

    if (_searchMarkerAdded) {
      _mapController!.deleteOverlay(NOverlayInfo(type: NOverlayType.marker, id: _searchMarkerId));
      _searchMarkerAdded = false;
    }

    final bytes = await _markerImageFactory.createPinMarkerImage();
    if (!mounted) return;
    final icon = await overlayImageFromBytes(bytes);

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
        zoom: _placeFocusZoom,
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

    // 스택 펼침 중 지도 이동 → 접기 (피그마 B안: 지도 이동 시 다시 접힘).
    // 펼침 직후의 자체 카메라 이동은 기준값과 같아 접히지 않는다.
    if (_expandedStackId != null &&
        _stackFanBaseTarget != null &&
        _stackFanBaseZoom != null) {
      final movedAway =
          (currentTarget.latitude - _stackFanBaseTarget!.latitude).abs() >
                  0.0005 ||
              (currentTarget.longitude - _stackFanBaseTarget!.longitude).abs() >
                  0.0005 ||
              (currentZoom - _stackFanBaseZoom!).abs() > 0.5;
      if (movedAway) {
        _collapseStackFan();
      }
    }

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

  // 공용 헬퍼 위임 — 글자 수 제한은 marker_constants.dart에서 관리.
  String _truncateMarkerTitle(String title) => truncateMarkerCaption(title);

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
    // 지도 탭 = 펼침도 접는다 (피그마 B안: 재탭/이동 시 접힘)
    _collapseStackFan();
    setState(() {
      _selectedSymbol = null;
      _selectedPlace = null;
      _isLoadingPlace = false;
      _selectedGroupIndex = null;
      _selectedPostIndex = null;
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
        // 사진 마커만 원래 크기로 복원 (텍스트 마커는 카드/점 크기 가변이라 제외)
        // 크기는 score 위계(42/50/58/66) 기준값으로 — 고정 50 아님.
        if (!_textMarkerCardMode.containsKey(prevId)) {
          final baseSize = _markerBaseSize[prevId] ?? _normalMarkerSize;
          try {
            prevMarker.setSize(Size(baseSize, baseSize));
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
        // 선택 강조: 사진 마커는 살짝 확대 (아이콘 재합성 없이 setSize만 —
        // iOS 마커 이미지 캐시 경합 리스크 없음. marker_constants 참고)
        // 확대 기준도 위계 크기 — 핫플은 66 x 1.18 까지 커진다.
        if (!_textMarkerCardMode.containsKey(markerId)) {
          final baseSize = _markerBaseSize[markerId] ?? _normalMarkerSize;
          try {
            marker.setSize(Size(
                baseSize * kSelectedMarkerScale,
                baseSize * kSelectedMarkerScale));
          } catch (_) {/* same */}
        }
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

  /// 클러스터 마커 빌더.
  /// 아이콘 = score 최상위 마커 이미지 + 우상단 +N 뱃지(합성). caption = 타이틀(마커 아래).
  void _buildClusterMarker(NClusterInfo info, NClusterMarker clusterMarker) {
    debugPrint('[map] clusterBuilder called size=${info.size}');
    try {
    // children 중 score 최대 마커 식별 + 스택 글 수 합산
    String? topId;
    String? topTitle;
    NLatLng? topPosition;
    bool topCanCard = false;
    int topOwnCount = 1;
    double topScore = -1;
    // 클러스터가 품은 총 글 수 — 스택 마커(count 2+)를 포함하므로
    // 마커 수(info.size)가 아니라 count 태그 합계를 뱃지에 표시.
    int totalCount = 0;
    for (final child in info.children) {
      final childCount = int.tryParse(child.tags['count'] ?? '1') ?? 1;
      totalCount += childCount;
      final s = double.tryParse(child.tags['score'] ?? '0') ?? 0;
      if (s > topScore) {
        topScore = s;
        topId = child.id;
        topTitle = child.tags['title'];
        topPosition = child.position;
        topCanCard = child.tags['canCard'] == '1';
        topOwnCount = childCount;
      }
    }

    if (topId != null) {
      // 현재 빌드 시점의 총 글 수 기록 → 비동기 합성 결과의 stale 적용 방지
      _clusterCurrentSize[topId] = totalCount;

      if (info.size == 1) {
        // 단일 마커가 클러스터 빌더 거치는 경우 — 일반 마커처럼 표시.
        // 아이콘 캐시에 스택 합성본이 들어 있으므로 뱃지 추가 합성 불필요.
        // 크기는 score 위계 기준값(42/50/58/66).
        final base = _markerIconCache[topId];
        if (base != null) {
          final baseSize = _markerBaseSize[topId] ?? _normalMarkerSize;
          clusterMarker.setIcon(base);
          clusterMarker.setSize(Size(baseSize, baseSize));
        }
      } else {
        final cacheKey = '${topId}_$totalCount';
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
          _composeClusterIconAsync(topId, totalCount, clusterMarker);
        }
      }
    }

    // 마커 아래 타이틀 (일반 마커와 동일)
    final title = (topTitle ?? '').trim();
    clusterMarker.setCaption(NOverlayCaption(
      text: title.isEmpty ? '' : _truncateMarkerTitle(title),
      textSize: _markerCaptionTextSize,
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
      final bool canCard = topCanCard;
      final bool isStack = topOwnCount > 1;
      clusterMarker.setOnTapListener((_) async {
        _focusNode.unfocus();
        // 스택 마커 → 원형 펼침 (B안).
        if (isStack) {
          await _expandStackFan(singleId);
          return;
        }
        // 단일 마커 = 줌인 + 카메라 무빙 + 카드 오픈 한 번에 (위 탭 핸들러와 동일).
        final idx = _postGroups
            .indexWhere((g) => g.isNotEmpty && g.first.id == singleId);
        if (idx < 0) return;
        _selectMarker(idx, minZoom: canCard ? _textCardCameraZoom : null);
      });
    }

    // 클러스터(size>1) 탭 = 카드 없이 대표(최고 score) 마커 위치로 카메라만
    // 이동 + kClusterTapZoom(18)까지 당긴다. 클러스터링(≤16)이 풀리고
    // 10~20m 간격 스택들도 확실히 벌어져 개별 마커가 보인다.
    // 카드는 사용자가 펼쳐진 마커를 직접 탭했을 때만 연다.
    if (info.size > 1 && topPosition != null) {
      final target = topPosition;
      clusterMarker.setOnTapListener((_) async {
        if (_mapController == null) return;
        _focusNode.unfocus();
        final camera = await _mapController!.getCameraPosition();
        final update = NCameraUpdate.scrollAndZoomTo(
          target: target,
          zoom: camera.zoom < kClusterTapZoom ? kClusterTapZoom : camera.zoom,
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
  /// [count] = 클러스터가 품은 총 글 수 (스택 마커의 count 태그 합계).
  /// 클러스터링 incremental 호출(count 증가) 동안 카운트업 잔상을 피하려고
  /// 합성 후 짧게 기다린 뒤 그 시점의 최종 count일 때만 setIcon 적용.
  Future<void> _composeClusterIconAsync(
      String topId, int count, NClusterMarker clusterMarker) async {
    final baseBytes = _markerBytesCache[topId];
    if (baseBytes == null) {
      debugPrint('[map] composeCluster skip (no baseBytes) topId=$topId count=$count');
      return;
    }
    debugPrint('[map] composeCluster start topId=$topId count=$count');
    try {
      final composedBytes = await _markerImageFactory.addClusterBadge(baseBytes, count);
      final composedIcon = await overlayImageFromBytes(composedBytes);
      if (!mounted) return;
      _clusterIconCache['${topId}_$count'] = composedIcon;

      // 클러스터링 안정 대기 — 그 사이 같은 topId의 더 큰 count가 도착하면 stale 처리
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      if (_clusterCurrentSize[topId] != count) {
        debugPrint('[map] composeCluster stale topId=$topId count=$count '
            'now=${_clusterCurrentSize[topId]}');
        return; // 이미 다른 count로 변경됨
      }
      // delay 사이 native에서 클러스터가 사라졌을 수 있음 — isAdded로 한 번 더 검증.
      if (!clusterMarker.isAdded) {
        debugPrint('[map] composeCluster notAdded topId=$topId count=$count');
        return;
      }

      // isAdded 체크 후 setIcon/setSize 사이에 native에서 클러스터가 제거된
      // 잔여 윈도우 보호 (Android 한정 race; iOS는 native가 빨라 무증상).
      try {
        clusterMarker.setIcon(composedIcon);
        clusterMarker.setSize(const Size(_clusterMarkerSize, _clusterMarkerSize));
        debugPrint('[map] composeCluster applied topId=$topId count=$count');
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
  /// [keepStackFan]: true 면 스택 펼침 유지 — 이동 목표를 펼침 기준값으로
  /// 갱신해 카메라 idle 의 자동 접힘 판정을 통과시킨다 (펼침 마커 탭 경로).
  Future<void> _moveCameraToMarker(
    NLatLng markerPos, {
    double? zoom,
    bool keepStackFan = false,
  }) async {
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
    if (keepStackFan && _expandedStackId != null) {
      // idle 콜백이 애니메이션 완료 전에 돌 수 있어 updateCamera 이전에 갱신.
      _stackFanBaseTarget = adjustedTarget;
      _stackFanBaseZoom = targetZoom;
    }
    await _mapController!.updateCamera(update);
  }

  /// 주어진 인덱스의 마커를 선택: 카메라 이동(필요시 kClusterExpandZoom까지 줌인)
  /// + z-index 부스트 + 스트립 위치 갱신.
  /// 마커 탭, 스트립 탭, 카드 좌우 스와이프 등 모든 그룹 전환 경로의 공통 진입점.
  ///
  /// [postIndex]: 그룹 내 특정 글 페이지로 카드를 연다 (스택 펼침 마커 탭).
  /// [moveCamera]: false 면 카메라 이동·하이라이트 없이 카드만 연다
  /// (펼침 상태에서는 이미 줌인돼 있고 원본 스택 마커는 숨김 상태).
  /// [minZoom]: 줌인 하한 재정의 — 기본은 kClusterExpandZoom.
  /// 텍스트 카드 마커는 카드 표시 줌(kTextCardCameraZoom)까지 당긴다.
  Future<void> _selectMarker(
    int idx, {
    int? postIndex,
    bool moveCamera = true,
    double? minZoom,
  }) async {
    if (idx < 0 || idx >= _postGroups.length) return;
    if (_mapController == null) return;
    final post = _postGroups[idx].first;
    final markerPos = _markerRefs[post.id]?.position
        ?? NLatLng(post.latitude, post.longitude);

    setState(() {
      _searchResults = [];
      _selectedSymbol = null;
      _selectedPlace = null;
      _isLoadingPlace = false;
      _selectedGroupIndex = idx;
      _selectedPostIndex = postIndex;
    });
    if (!moveCamera) return;

    final camera = await _mapController!.getCameraPosition();
    // 클러스터 탭과 동일한 깊이(kClusterExpandZoom)로 — 어디서 탭하든 일관되게
    // 인접 마커가 구분되는 줌까지 들어간다. 이미 더 깊으면 현재 줌 유지.
    final double floorZoom = minZoom ?? _clusterExpandZoom;
    final targetZoom = camera.zoom < floorZoom ? floorZoom : camera.zoom;
    _applySelectionHighlight(post.id);
    await _moveCameraToMarker(markerPos, zoom: targetZoom);
  }

  // ── 스택 원형 펼침 (피그마 "15 B안 — 탭하면 부채꼴 펼침") ────────────────

  /// 스택 마커 탭 → kStackFanZoom 까지 당긴 뒤 그룹 글들을 실제 좌표 중심
  /// 원형으로 펼친다. 점선 다리 = 실제 좌표 표시. 원본 스택 마커는 숨김.
  /// 지도 이동/지도 탭 시 [_collapseStackFan] 으로 접힘.
  /// [openCard]: false 면 카드는 건드리지 않는다 — 카드 스와이프로 스택
  /// 그룹에 진입한 경우 카드가 이미 해당 페이지를 보여주는 중.
  Future<void> _expandStackFan(String stackId, {bool openCard = true}) async {
    if (_mapController == null) return;
    final gIdx = _postGroups
        .indexWhere((g) => g.isNotEmpty && g.first.id == stackId);
    if (gIdx < 0) return;
    final group = _postGroups[gIdx];
    if (group.length < 2) return;

    // 경합 가드 — 카드 연속 스와이프 등으로 펼침이 겹쳐 호출되면
    // 이전 호출은 await 지점 이후를 포기한다 (고아 오버레이 방지).
    final int seq = ++_stackFanSeq;

    // await 이전에 캡처 (context 사용 규칙)
    final captionTokens = AppColors.of(context);

    await _collapseStackFan();

    final top = group.first;
    final center = NLatLng(top.latitude, top.longitude);

    // 1) 펼침 줌까지 당기면서 중심(실제 위치)을 카드 위(화면 22%)에 배치 —
    // 펼침과 동시에 대표 글 카드가 열리므로 일반 마커 선택과 같은 프레이밍.
    final camera = await _mapController!.getCameraPosition();
    final double fanZoom =
        camera.zoom < kStackFanZoom ? kStackFanZoom : camera.zoom;
    await _moveCameraToMarker(center, zoom: fanZoom);
    if (!mounted || _mapController == null || seq != _stackFanSeq) return;

    // 2) 화면 dp 반지름 → 위경도 오프셋 변환
    final settled = await _mapController!.getCameraPosition();
    final meterPerDp = _mapController!.getMeterPerDpAtLatitude(
      latitude: center.latitude,
      zoom: settled.zoom,
    );
    // 글 수가 많으면 원주가 모자라지 않게 반지름 자동 확대
    final double radiusDp = max(
      kStackFanBaseRadiusDp,
      group.length * (kNormalMarkerSize + kStackFanMarkerGapDp) / (2 * pi),
    );
    final double radiusM = radiusDp * meterPerDp;
    final double dLat = radiusM / 111320.0;
    final double dLng =
        radiusM / (111320.0 * cos(center.latitude * pi / 180));

    // 3) 오버레이 구성: 중심점 + 점선 다리 + 펼침 마커
    // (마커·폴리라인·원 혼합 — addOverlayAll 시그니처 타입에 맞춘다)
    final overlays = <NAddableOverlay<NOverlay<void>>>{};

    // 중심점 = 실제 위치. GPS 현재위치 스타일 이중 원으로 강조 —
    // 연한 할로(넓게) + 진한 점(화이트 링). 할로가 점 아래에 깔리도록 z 분리.
    final haloCircle = NCircleOverlay(
      id: _stackFanCenterHaloId,
      center: center,
      radius: kStackFanCenterHaloRadiusDp * meterPerDp,
      color: captionTokens.primary.withValues(alpha: 0.18),
    )..setGlobalZIndex(_stackFanZIndex - 2);
    final dotCircle = NCircleOverlay(
      id: _stackFanCenterId,
      center: center,
      radius: kStackFanCenterDotRadiusDp * meterPerDp,
      color: captionTokens.primary,
      outlineColor: captionTokens.surface,
      outlineWidth: 3,
    )..setGlobalZIndex(_stackFanZIndex - 1);
    overlays.add(haloCircle);
    overlays.add(dotCircle);
    _stackFanCenterAdded = true;

    for (int i = 0; i < group.length; i++) {
      final post = group[i];
      // 12시 방향부터 시계방향 배치
      final double angle = 2 * pi * i / group.length;
      final pos = NLatLng(
        center.latitude + dLat * cos(angle),
        center.longitude + dLng * sin(angle),
      );
      _stackFanPositions[post.id] = pos;

      // 점선 다리 — 실제 좌표(중심) 표시
      final legId = 'stack_fan_leg_${post.id}';
      overlays.add(NPolylineOverlay(
        id: legId,
        coords: [center, pos],
        color: captionTokens.borderStrong,
        width: 1.5,
        pattern: kStackFanLegPattern,
      ));
      _stackFanLegIds.add(legId);

      // 펼침 마커 — 글 각각의 아이콘 (사진=링 썸네일, 텍스트=말풍선 점)
      NOverlayImage? icon;
      try {
        final Uint8List bytes;
        if (post.fileInfoList.isNotEmpty) {
          final stream = await _markerImageFactory
              .getImageStream(post.fileInfoList.first.fileUrl);
          bytes = await _markerImageFactory.createMarkerImage(
            stream,
            ringColor: markerRingColor(
              isOwner: post.isOwner,
              createdAt: post.createdAt,
            ),
          );
        } else {
          bytes = await _markerImageFactory.createTextDotImage();
        }
        icon = await overlayImageFromBytes(bytes);
      } catch (e) {
        debugPrint('[map] 스택 펼침 아이콘 생성 실패 ${post.id}: $e');
      }

      final fanId = 'stack_fan_${post.id}';
      final title = displayTitle(post.title, post.content);
      final fanMarker = NMarker(
        id: fanId,
        position: pos,
        icon: icon,
        size: const Size(kNormalMarkerSize, kNormalMarkerSize),
        caption: NOverlayCaption(
          text: _truncateMarkerTitle(title),
          textSize: _markerCaptionTextSize,
          color: captionTokens.textPrimary,
          haloColor: captionTokens.background,
        ),
      );
      fanMarker.setGlobalZIndex(_stackFanZIndex + i);
      final int postIdx = i;
      fanMarker.setOnTapListener((_) {
        _focusNode.unfocus();
        // 그룹 인덱스는 재조회로 바뀔 수 있어 탭 시점에 재탐색
        final idx = _postGroups
            .indexWhere((g) => g.isNotEmpty && g.first.id == stackId);
        if (idx < 0) return;
        _selectMarker(idx, postIndex: postIdx, moveCamera: false);
        // 기존 마커 선택과 동일하게 — 탭한 펼침 마커가 카드 위(화면 22%)에
        // 보이도록 이동. keepStackFan 으로 펼침은 유지.
        // focused 갱신 → 카드 페이지 에코(onPostChanged)의 중복 이동 방지.
        _stackFanFocusedPostId = post.id;
        _moveCameraToMarker(pos, keepStackFan: true);
      });
      overlays.add(fanMarker);
      _stackFanMarkerIds.add(fanId);
    }

    if (!mounted || _mapController == null || seq != _stackFanSeq) return;
    await _mapController!.addOverlayAll(overlays);

    // 원본 스택 마커 숨김 (접을 때 복원)
    try {
      _markerRefs[stackId]?.setIsVisible(false);
    } catch (_) {}

    _expandedStackId = stackId;
    _stackFanBaseTarget = settled.target;
    _stackFanBaseZoom = settled.zoom;

    // 펼침과 동시에 대표(위계 최고) 글의 바텀 카드 오픈 (2026-07-13 피드백).
    // 그룹 인덱스는 재조회로 바뀔 수 있어 이 시점에 재탐색.
    if (openCard) {
      final int cardIdx = _postGroups
          .indexWhere((g) => g.isNotEmpty && g.first.id == stackId);
      if (cardIdx >= 0) {
        // 카드가 대표 글로 이동하며 내는 onPostChanged 에코에 카메라가
        // 다시 움직이지 않도록 — 펼침 직후 프레이밍(중심 22%)을 유지.
        _stackFanFocusedPostId = stackId;
        _selectMarker(cardIdx, postIndex: 0, moveCamera: false);
      }
    }
  }

  /// 카드 페이지 이동 팔로우 — 펼침 상태에서 같은 스택 안의 다른 글로
  /// 넘어가면 해당 펼침 마커가 카드 위(22%)에 오도록 카메라 이동.
  /// 펼침이 아니거나 다른 그룹이면 무시 (그룹 경계는 onGroupChanged 가 처리).
  void _followStackFanPost(int groupIndex, int postIndex) {
    if (_expandedStackId == null) return;
    if (groupIndex < 0 || groupIndex >= _postGroups.length) return;
    final group = _postGroups[groupIndex];
    if (group.isEmpty || group.first.id != _expandedStackId) return;
    if (postIndex < 0 || postIndex >= group.length) return;
    final postId = group[postIndex].id;
    if (postId == _stackFanFocusedPostId) return; // 탭 에코 등 중복 방지
    final pos = _stackFanPositions[postId];
    if (pos == null) return;
    _stackFanFocusedPostId = postId;
    _moveCameraToMarker(pos, keepStackFan: true);
  }

  /// 펼침 해제 — 오버레이 제거 + 원본 스택 마커 복원.
  Future<void> _collapseStackFan() async {
    if (_expandedStackId == null) return;
    final stackId = _expandedStackId!;
    _expandedStackId = null;
    _stackFanBaseTarget = null;
    _stackFanBaseZoom = null;
    _stackFanPositions.clear();
    _stackFanFocusedPostId = null;

    for (final id in _stackFanMarkerIds) {
      try {
        _mapController?.deleteOverlay(
            NOverlayInfo(type: NOverlayType.marker, id: id));
      } catch (_) {}
    }
    _stackFanMarkerIds.clear();
    for (final id in _stackFanLegIds) {
      try {
        _mapController?.deleteOverlay(
            NOverlayInfo(type: NOverlayType.polylineOverlay, id: id));
      } catch (_) {}
    }
    _stackFanLegIds.clear();
    if (_stackFanCenterAdded) {
      try {
        _mapController?.deleteOverlay(NOverlayInfo(
            type: NOverlayType.circleOverlay, id: _stackFanCenterId));
      } catch (_) {}
      try {
        _mapController?.deleteOverlay(NOverlayInfo(
            type: NOverlayType.circleOverlay, id: _stackFanCenterHaloId));
      } catch (_) {}
      _stackFanCenterAdded = false;
    }

    try {
      _markerRefs[stackId]?.setIsVisible(true);
    } catch (_) {}
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
              initialCameraPosition:
                  NCameraPosition(target: seoulCityHall, zoom: _defaultEntryZoom),
              consumeSymbolTapEvents: true,
              // 기본 지도 POI 심볼 축소 — 공용 상수 (모든 지도 화면 동일).
              symbolScale: kMapSymbolScale,
              minZoom: 10,
              maxZoom: 20,
              // 다크모드일 때만 navi 타입 + 야간 모드 (라이브러리 한계: nightMode는 navi 전용)
              mapType: isDark ? NMapType.navi : NMapType.basic,
              nightModeEnable: isDark,
            ),
            clusterOptions: NaverMapClusteringOptions(
              // 줌 16까지 클러스터링, 17+ 부터는 모든 마커(스택 포함) 펼침.
              // 기본 진입 줌(16.5)에서 화면상 겹치는 마커(40dp)만 묶어
              // 스택끼리 포개지는 문제 해소. 클러스터 탭 → 대표 선택 + 17.5 줌인.
              enableZoomRange: const NInclusiveRange(0, 16),
              // 0으로 두어 size 1→2→3 점진 증가하는 카운트업 잔상 제거
              animationDuration: Duration.zero,
              // 병합 거리 — 공용 상수 (내지도와 동일).
              mergeStrategy: const NClusterMergeStrategy(
                willMergedScreenDistance: kClusterMergeDistances,
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
                size: 36,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          // '내 지도' 진입 버튼 — 우측 하단(네비게이션 바 위). 카드 열리면 페이드아웃.
          Positioned(
            right: 16,
            bottom: 45,
            child: IgnorePointer(
              ignoring: _isAnyCardOpen,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isAnyCardOpen ? 0 : 1,
                child: _buildMyMapButton(),
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
                      // 스택 펼침 마커 탭 → 그룹 내 해당 글 페이지로 바로 연다.
                      initialPostIndex: _selectedPostIndex,
                      // 확장 카드 상단 여백. 이 화면은 root의 bottomNavigationBar
                      // (높이 64 + 하단 safe area)만큼 본문이 줄어든 영역이라,
                      // 네비바 소비 높이를 더해 카드 상단 위치를 보정한다.
                      // 비율(0.18)을 키울수록 카드가 더 아래에서 시작한다(짧아짐).
                      // 확장 시 검색바는 페이드아웃돼 가려져도 무방.
                      minTopMargin: MediaQuery.sizeOf(context).height * 0.15 +
                          64 +
                          MediaQuery.paddingOf(context).bottom,
                      onClose: () {
                        setState(() {
                          _selectedGroupIndex = null;
                          _isCardExpanded = false;
                        });
                        _applySelectionHighlight(null);
                      },
                      onGroupChanged: (newIdx) {
                        if (newIdx >= 0 &&
                            newIdx < _postGroups.length &&
                            _postGroups[newIdx].length >= 2) {
                          // 카드 스와이프로 다른 스택 그룹 진입 → 카메라 이동
                          // + 그 스택도 펼친다. 카드는 이미 해당 페이지를
                          // 보여주는 중이라 다시 열지 않는다 (openCard: false).
                          setState(() {
                            _selectedGroupIndex = newIdx;
                            _selectedPostIndex = null;
                          });
                          _expandStackFan(
                            _postGroups[newIdx].first.id,
                            openCard: false,
                          );
                        } else {
                          _selectMarker(newIdx);
                        }
                      },
                      onPostChanged: _followStackFanPost,
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

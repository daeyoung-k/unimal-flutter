import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:unimal/screens/map/bottom_card/map_bottom_card.dart';
import 'package:unimal/service/board/board_api_service.dart';
import 'package:unimal/service/image/image_service.dart';
import 'package:unimal/service/map/models/map_post.dart';
import 'package:unimal/service/map/naver_search_service.dart';
import 'package:unimal/state/nav_controller.dart';
import 'package:unimal/theme/app_colors.dart';

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
  // 현재 z-index 부스트되어 있는 마커 ID (한 번에 1개만 부스트).
  String? _highlightedMarkerId;
  // 선택 마커가 사용하는 z-index. score 기반(약 200,000 + score)보다 충분히 큰 값.
  static const int _selectedMarkerZIndex = 999999999;
  // 선택 마커가 표시될 때 사용하는 핀 아이콘. onMapReady 시점에 lazy init.
  NOverlayImage? _pinIcon;
  // 선택 핀 마커 표시 사이즈 (일반 마커 32보다 약간 크게 두드러짐).
  static const _selectedMarkerWidth = 36.0;
  static const _selectedMarkerHeight = 46.0;
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

  Worker? _pendingLocationWorker;

  static const _searchMarkerId = 'search_result_marker';
  static const _dismissThreshold = 80.0;

  // 마커 크기 — 한 곳에서 조절
  static const _normalMarkerSize = 32.0; // 일반(단일) 마커
  static const _clusterMarkerSize = 42.0; // 클러스터(2개 이상 합쳐진) 마커

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
      );
    } else {
      final camera = await _mapController!.getCameraPosition();
      if (!mounted) return;
      await _loadMapMarkers(
        camera.target.latitude,
        camera.target.longitude,
        camera.zoom.round(),
      );
    }
  }

  void _applyPendingLocation() {
    final nav = Get.find<NavController>();
    final lat = nav.pendingMapLat.value;
    final lng = nav.pendingMapLng.value;
    if (lat == null || lng == null) return;
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
    _mapController?.updateCamera(
      NCameraUpdate.withParams(zoom: 15),
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
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 5),
        );
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (!mounted) return;
      if (position != null) {
        _mapController?.updateCamera(
          NCameraUpdate.scrollAndZoomTo(
            target: NLatLng(position.latitude, position.longitude),
            zoom: 15,
          ),
        );
        _loadMapMarkers(position.latitude, position.longitude, 15);
      } else {
        _loadMapMarkers(seoulCityHall.latitude, seoulCityHall.longitude, 15);
      }
    } catch (_) {
      if (mounted) {
        _loadMapMarkers(seoulCityHall.latitude, seoulCityHall.longitude, 15);
      }
    }
  }

  Future<void> _loadMapMarkers(double latitude, double longitude, int zoom) async {
    if (_mapController == null) return;
    if (_isLoadingMarkers) return; // 중복 호출 방지
    _isLoadingMarkers = true;
    try {
      await _loadMapMarkersInternal(latitude, longitude, zoom);
    } finally {
      _isLoadingMarkers = false;
    }
  }

  Future<void> _loadMapMarkersInternal(
      double latitude, double longitude, int zoom) async {
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
    final posts = await _boardApiService.getMapLocationPosts(
      latitude: latitude,
      longitude: longitude,
      zoom: zoom,
    );
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
    const maxJitterPerGroup = 5; // 한 좌표 그룹당 최대 jitter 마커 수
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

    // 1) 기존에 있고 새에 없는 마커만 제거
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
        // 부스트되어 있던 마커가 사라지면 하이라이트 상태도 해제
        if (_highlightedMarkerId == id) {
          _highlightedMarkerId = null;
        }
      }
    }

    // 2) 각 게시글마다 마커 + single-post visibleGroup 추가
    final List<List<MapPost>> visibleGroups = [];

    for (final data in markerData) {
      final topPost = data.post;
      final pos = data.position;

      // 이미 화면에 있는 마커 → 재사용
      if (_mapMarkerIds.contains(topPost.id)) {
        visibleGroups.add([topPost]);
        continue;
      }

      // 신규 마커 — 이미지 fetch + 생성
      NOverlayImage? icon;
      Uint8List? baseBytes;
      if (topPost.fileInfoList.isNotEmpty) {
        try {
          final firstUrl = topPost.fileInfoList.first.fileUrl;
          final stream = await _imageService.getImageStream(firstUrl);
          baseBytes = await _imageService.createMarkerImage(stream);
          icon = await NOverlayImage.fromByteArray(baseBytes);
        } catch (_) {
          continue;
        }
      }

      visibleGroups.add([topPost]);

      // 클러스터 빌더에서 재사용할 캐시 저장
      if (icon != null) {
        _markerIconCache[topPost.id] = icon;
      }
      if (baseBytes != null) {
        _markerBytesCache[topPost.id] = baseBytes;
      }

      final marker = NClusterableMarker(
        id: topPost.id,
        position: pos,
        icon: icon,
        size: const Size(_normalMarkerSize, _normalMarkerSize),
        tags: {
          'score': topPost.score.toString(),
          'title': topPost.title,
        },
        caption: NOverlayCaption(
          text: _truncateMarkerTitle(topPost.title),
          textSize: 13,
          color: captionTokens.textPrimary,
          haloColor: captionTokens.background,
        ),
      );

      final baseZIndex = 200000 + topPost.score.toInt();
      marker.setGlobalZIndex(baseZIndex);
      _markerRefs[topPost.id] = marker;
      _markerBaseZIndex[topPost.id] = baseZIndex;

      final markerPostId = topPost.id;
      final markerLatLng = pos;
      marker.setOnTapListener((_) {
        _focusNode.unfocus();
        final idx = _postGroups
            .indexWhere((g) => g.isNotEmpty && g.first.id == markerPostId);
        if (idx < 0) return;
        setState(() {
          _searchResults = [];
          _selectedSymbol = null;
          _selectedPlace = null;
          _isLoadingPlace = false;
          _selectedGroupIndex = idx;
        });
        _applySelectionHighlight(markerPostId);
        _moveCameraToMarker(markerLatLng);
      });

      if (!mounted) return;
      _mapController!.addOverlay(marker);
      _mapMarkerIds.add(topPost.id);
    }

    if (!mounted) return;
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
    setState(() => _searchResults = []);
    _searchController.text = result.title;

    final position = NLatLng(result.lat, result.lng);

    _mapController?.updateCamera(
      NCameraUpdate.scrollAndZoomTo(target: position, zoom: 16),
    );

    _addSearchMarker(result, position);
  }

  void _addSearchMarker(NaverLocalSearchResult result, NLatLng position) {
    if (_mapController == null) return;

    _mapController!.deleteOverlay(NOverlayInfo(type: NOverlayType.marker, id: _searchMarkerId));

    final marker = NMarker(
      id: _searchMarkerId,
      position: position,
      size: const Size(26, 36),
    );

    _mapController!.addOverlay(marker);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchResults = []);
    _focusNode.unfocus();
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
    if (!zoomChanged && !positionChanged) return;

    // Debounce 500ms — 카메라 멈춘 시점에 1회 조회
    _cameraDebounce?.cancel();
    _cameraDebounce = Timer(const Duration(milliseconds: 500), () {
      _lastQueriedTarget = currentTarget;
      _lastQueriedZoom = currentZoom;
      _loadMapMarkers(
        currentTarget.latitude,
        currentTarget.longitude,
        currentZoom.round(),
      );
    });
  }

  String _truncateMarkerTitle(String title) =>
      title.length > 10 ? '${title.substring(0, 10)}...' : title;

  void _closeAllCards() {
    setState(() {
      _selectedSymbol = null;
      _selectedPlace = null;
      _isLoadingPlace = false;
      _selectedGroupIndex = null;
      _cardDragOffset = 0.0;
    });
    _applySelectionHighlight(null);
  }

  /// 선택된 마커를 푸른 핀으로 즉시 교체하고 z-index를 다른 마커보다 위로 부스트.
  /// 이전에 선택되어 있던 마커가 있으면 원래 사진 아이콘 + score 기반 z-index로 복원.
  /// [markerId]가 null이면 부스트/핀 해제만 수행.
  /// idempotent: 재조회로 마커 객체가 새로 만들어진 케이스에도 안전하게 재적용됨.
  void _applySelectionHighlight(String? markerId) {
    final prevId = _highlightedMarkerId;
    if (prevId != null && prevId != markerId) {
      final prevMarker = _markerRefs[prevId];
      if (prevMarker != null) {
        final baseZ = _markerBaseZIndex[prevId];
        if (baseZ != null) prevMarker.setGlobalZIndex(baseZ);
        final originalIcon = _markerIconCache[prevId];
        if (originalIcon != null) prevMarker.setIcon(originalIcon);
        prevMarker
            .setSize(const Size(_normalMarkerSize, _normalMarkerSize));
      }
    }
    _highlightedMarkerId = markerId;
    if (markerId != null) {
      final marker = _markerRefs[markerId];
      if (marker != null) {
        marker.setGlobalZIndex(_selectedMarkerZIndex);
        if (_pinIcon != null) {
          marker.setIcon(_pinIcon);
          marker.setSize(const Size(
            _selectedMarkerWidth,
            _selectedMarkerHeight,
          ));
        }
      }
    }
  }

  /// 클러스터 마커 빌더.
  /// 아이콘 = score 최상위 마커 이미지 + 우상단 +N 뱃지(합성). caption = 타이틀(마커 아래).
  void _buildClusterMarker(NClusterInfo info, NClusterMarker clusterMarker) {
    // children 중 score 최대 마커 식별
    String? topId;
    String? topTitle;
    NLatLng? topPosition;
    double topScore = -1;
    for (final child in info.children) {
      final s = double.tryParse(child.tags['score'] ?? '0') ?? 0;
      if (s > topScore) {
        topScore = s;
        topId = child.id;
        topTitle = child.tags['title'];
        topPosition = child.position;
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

    // 클러스터(size>1) 탭 → 줌 15+ 자동 확대. 줌 15부터 클러스터링이 비활성
    // 이므로 자연스럽게 풀리며, 사용자가 펼쳐진 jitter 마커를 한 번 더 탭해서
    // 카드/스트립으로 진입.
    if (info.size > 1 && topPosition != null) {
      final target = topPosition;
      clusterMarker.setOnTapListener((_) async {
        if (_mapController == null) return;
        _focusNode.unfocus();
        final camera = await _mapController!.getCameraPosition();
        final nextZoom = camera.zoom < 15 ? 15.0 : camera.zoom;
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
  }

  /// 클러스터 뱃지가 합성된 아이콘을 비동기로 만들어 캐시에 저장하고 마커에 적용.
  /// 클러스터링 incremental 호출(size 1→2→3..) 동안 카운트업 잔상을 피하려고
  /// 합성 후 짧게 기다린 뒤 그 시점의 최종 size일 때만 setIcon 적용.
  Future<void> _composeClusterIconAsync(
      String topId, int size, NClusterMarker clusterMarker) async {
    final baseBytes = _markerBytesCache[topId];
    if (baseBytes == null) return;
    try {
      final composedBytes = await _imageService.addClusterBadge(baseBytes, size);
      final composedIcon = await NOverlayImage.fromByteArray(composedBytes);
      if (!mounted) return;
      _clusterIconCache['${topId}_$size'] = composedIcon;

      // 클러스터링 안정 대기 — 그 사이 같은 topId의 더 큰 size가 도착하면 stale 처리
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      if (_clusterCurrentSize[topId] != size) return; // 이미 다른 size로 변경됨

      clusterMarker.setIcon(composedIcon);
      clusterMarker.setSize(const Size(_clusterMarkerSize, _clusterMarkerSize));
    } catch (_) {}
  }

  /// 마커가 화면 세로 25% 지점, 가로 중앙에 보이도록 카메라 이동 (fly 600ms).
  /// 알고리즘: 카메라 target T를 (markerPos + (현재 카메라 target 좌표 - 원하는 픽셀 좌표))로 두면
  /// 새 카메라에서 markerPos가 원하는 픽셀에 정확히 매핑됨 (줌 동일 가정).
  Future<void> _moveCameraToMarker(NLatLng markerPos) async {
    if (_mapController == null) return;
    final size = MediaQuery.sizeOf(context);

    final cameraTarget =
        (await _mapController!.getCameraPosition()).target;
    final desiredPixel = NPoint(size.width / 2, size.height * 0.22);
    final desiredCoord =
        await _mapController!.screenLocationToLatLng(desiredPixel);

    // 카메라 target 좌표 - 원하는 픽셀의 현재 좌표 = 필요한 좌표 보정값
    final dLat = cameraTarget.latitude - desiredCoord.latitude;
    final dLng = cameraTarget.longitude - desiredCoord.longitude;

    final adjustedTarget = NLatLng(
      markerPos.latitude + dLat,
      markerPos.longitude + dLng,
    );

    final update = NCameraUpdate.scrollAndZoomTo(target: adjustedTarget)
      ..setAnimation(
        animation: NCameraAnimation.fly,
        duration: const Duration(milliseconds: 600),
      );
    _lastQueriedTarget = adjustedTarget;
    await _mapController!.updateCamera(update);
  }

  /// 선택 마커가 핀으로 즉시 교체될 수 있도록 onMapReady 시점에 핀 이미지를 1회 생성.
  Future<void> _preparePinIcon() async {
    try {
      final bytes = await _imageService.createPinMarkerImage();
      if (!mounted) return;
      _pinIcon = await NOverlayImage.fromByteArray(bytes);
    } catch (_) {
      // 핀 이미지 생성 실패 시: 선택 시 z-index 부스트만 적용 (방어)
    }
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
              // 줌 13 이하만 클러스터링, 14+ 부터는 모든 마커 펼침.
              // 라이브러리 enableZoomRange가 명세("zoom < max+1")대로 동작 안 하는 케이스
              // 관찰됨(줌 15.00에서도 클러스터링됨). 안전권으로 한 칸 더 낮춤.
              enableZoomRange: const NInclusiveRange(0, 13),
              // 0으로 두어 size 1→2→3 점진 증가하는 카운트업 잔상 제거
              animationDuration: Duration.zero,
              mergeStrategy: const NClusterMergeStrategy(
                willMergedScreenDistance: {
                  // 줌 10-12 (시·도): 100dp 이내 마커 묶음 (넓게)
                  NInclusiveRange(10, 12): 100.0,
                  // 줌 13 (구·동): 70dp (기본 보통)
                  NInclusiveRange(13, 13): 70.0,
                },
              ),
              clusterMarkerBuilder: _buildClusterMarker,
            ),
            onMapReady: (controller) {
              setState(() => _mapController = controller);
              _preparePinIcon();
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
            left: 16,
            right: 16,
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
            bottom: _selectedSymbol != null ? -_cardDragOffset : -200,
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
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
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
                      minTopMargin: MediaQuery.paddingOf(context).top + 12,
                      onCameraMove: _moveCameraToMarker,
                      onClose: () {
                        setState(() => _selectedGroupIndex = null);
                        _applySelectionHighlight(null);
                      },
                      onGroupChanged: (newIdx) {
                        setState(() => _selectedGroupIndex = newIdx);
                        if (newIdx >= 0 && newIdx < _postGroups.length) {
                          _applySelectionHighlight(
                              _postGroups[newIdx].first.id);
                        }
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

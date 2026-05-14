import 'dart:async';

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

class MapNaverScreens extends StatefulWidget {
  const MapNaverScreens({super.key});

  @override
  State<MapNaverScreens> createState() => _MapNaverScreensState();
}

class _MapNaverScreensState extends State<MapNaverScreens> {
  NaverMapController? _mapController;
  final ImageService _imageService = ImageService();
  final NaverSearchService _searchService = NaverSearchService();
  final BoardApiService _boardApiService = BoardApiService();
  final List<String> _mapMarkerIds = [];
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
  double _lastQueriedZoom = 14;

  // 카메라 이동 자동 조회 — debounce + lock
  Timer? _cameraDebounce;
  bool _isLoadingMarkers = false;

  Worker? _pendingLocationWorker;

  static const _searchMarkerId = 'search_result_marker';
  static const _dismissThreshold = 80.0;

  bool get _isAnyCardOpen => _selectedSymbol != null || _selectedPosts.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _pendingLocationWorker = ever(
      Get.find<NavController>().pendingMapLat,
      (_) => _applyPendingLocation(),
    );
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
    _pendingLocationWorker?.dispose();
    _debounce?.cancel();
    _cameraDebounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void refreshMap() {
    _mapController?.updateCamera(
      NCameraUpdate.withParams(zoom: 14),
    );
  }

  Future<void> _moveToCurrentLocationOrDefault() async {
    const seoulCityHall = NLatLng(37.5666, 126.979);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _loadMapMarkers(seoulCityHall.latitude, seoulCityHall.longitude, 14);
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
        _loadMapMarkers(seoulCityHall.latitude, seoulCityHall.longitude, 14);
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
            zoom: 14,
          ),
        );
        _loadMapMarkers(position.latitude, position.longitude, 14);
      } else {
        _loadMapMarkers(seoulCityHall.latitude, seoulCityHall.longitude, 14);
      }
    } catch (_) {
      if (mounted) {
        _loadMapMarkers(seoulCityHall.latitude, seoulCityHall.longitude, 14);
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

    // 같은 좌표끼리 그룹핑 + score 내림차순
    final Map<String, List<MapPost>> grouped = {};
    for (final post in posts) {
      final key = '${post.latitude.toStringAsFixed(3)},${post.longitude.toStringAsFixed(3)}';
      grouped.putIfAbsent(key, () => []).add(post);
    }
    final groupsList = grouped.values.map((g) {
      g.sort((a, b) => b.score.compareTo(a.score));
      return g;
    }).toList();

    // 새 결과의 대표 마커 ID 집합
    final newMarkerIds = groupsList.map((g) => g.first.id).toSet();

    // 1) 기존에 있고 새에 없는 마커만 제거
    for (final id in _mapMarkerIds.toList()) {
      if (!newMarkerIds.contains(id)) {
        try {
          _mapController!.deleteOverlay(NOverlayInfo(type: NOverlayType.marker, id: id));
        } catch (_) {}
        _mapMarkerIds.remove(id);
      }
    }

    // 2) 새 결과 순서대로 visibleGroups 구성 — 기존 마커는 재사용, 누락된 것만 신규 추가
    final List<List<MapPost>> visibleGroups = [];

    for (final postsAtLocation in groupsList) {
      final topPost = postsAtLocation.first;

      // 이미 화면에 있는 마커 → 재사용 (이미지 fetch / addOverlay 생략)
      if (_mapMarkerIds.contains(topPost.id)) {
        visibleGroups.add(postsAtLocation);
        continue;
      }

      // 신규 마커 — 이미지 fetch + 생성
      NOverlayImage? icon;
      if (topPost.fileInfoList.isNotEmpty) {
        try {
          final firstUrl = topPost.fileInfoList.first.fileUrl;
          final stream = await _imageService.getImageStream(firstUrl);
          final bytes = await _imageService.createMarkerImage(stream);
          icon = await NOverlayImage.fromByteArray(bytes);
        } catch (_) {
          continue; // 이미지 로드 실패 시 마커 + 그룹 모두 skip
        }
      }

      visibleGroups.add(postsAtLocation);

      final marker = NMarker(
        id: topPost.id,
        position: NLatLng(topPost.latitude, topPost.longitude),
        icon: icon,
        size: const Size(45, 45),
        caption: NOverlayCaption(
          text: _truncateMarkerTitle(topPost.title),
          textSize: 12,
          color: Colors.black,
          haloColor: Colors.white,
        ),
      );

      marker.setGlobalZIndex(200000 + topPost.score.toInt());

      // ID 기반으로 현재 _postGroups에서 인덱스 동적 검색 (재조회 후에도 정확)
      final markerPostId = topPost.id;
      final markerLatLng = NLatLng(topPost.latitude, topPost.longitude);
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
    return Scaffold(
      body: Stack(
        children: [
          NaverMap(
            options: NaverMapViewOptions(
              contentPadding: safeAreaPadding,
              initialCameraPosition: NCameraPosition(target: seoulCityHall, zoom: 14),
              consumeSymbolTapEvents: true,
              minZoom: 10,
              maxZoom: 20,
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
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
                    style: const TextStyle(
                      fontSize: 15,
                      fontFamily: 'Pretendard',
                    ),
                    decoration: InputDecoration(
                      hintText: '장소 검색',
                      hintStyle: const TextStyle(
                        color: Color(0xFF9E9E9E),
                        fontFamily: 'Pretendard',
                      ),
                      prefixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF4D91FF),
                                ),
                              ),
                            )
                          : const Icon(Icons.search, color: Color(0xFF9E9E9E)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, color: Color(0xFF9E9E9E), size: 20),
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x22000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
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
                          leading: const Icon(Icons.place_outlined, color: Color(0xFF4D91FF), size: 20),
                          title: Text(
                            result.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            result.roadAddress.isNotEmpty ? result.roadAddress : result.address,
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'Pretendard',
                              color: Color(0xFF9E9E9E),
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
          // 공유하기 버튼
          Positioned(
            right: 16,
            bottom: 40 + 56,
            child: GestureDetector(
              onTap: () => Get.find<NavController>().selectedIndex.value = 1,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF4D91FF),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x334D91FF),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
              ),
            ),
          ),
          // 내 위치 버튼
          Positioned(
            right: 16,
            bottom: 40,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: NMyLocationButtonWidget(
                key: ValueKey(_isAnyCardOpen),
                mapController: _mapController,
                borderRadius: BorderRadius.circular(22),
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
                      onClose: () => setState(() => _selectedGroupIndex = null),
                      onGroupChanged: (newIdx) =>
                          setState(() => _selectedGroupIndex = newIdx),
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

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 12,
            offset: Offset(0, -2),
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
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.place, color: Color(0xFF4D91FF), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: isLoading
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            symbol?.caption ?? '',
                            style: const TextStyle(
                              fontSize: 16,
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF4D91FF),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (address.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              address,
                              style: const TextStyle(
                                fontSize: 13,
                                fontFamily: 'Pretendard',
                                color: Color(0xFF9E9E9E),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, color: Color(0xFF9E9E9E), size: 20),
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

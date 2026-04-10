import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:get/get.dart';
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
  List<MapPost> _selectedPosts = [];

  // 카드 드래그 관련 상태
  double _cardDragOffset = 0.0;

  // 주변 스토리 조회 버튼 관련 상태
  bool _mapInitialized = false;
  bool _showNearbyButton = false;
  NLatLng? _lastQueriedTarget;
  double _lastQueriedZoom = 14;

  Worker? _pendingLocationWorker;

  static const _searchMarkerId = 'search_result_marker';
  static const _dismissThreshold = 80.0;
  static const _zoomChangeTrigger = 3;

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
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void refreshMap() {
    _mapController?.updateCamera(
      NCameraUpdate.withParams(zoom: 14),
    );
  }

  Future<void> _loadMapMarkers(double latitude, double longitude, int zoom) async {
    if (_mapController == null) return;

    // 기존 마커 제거
    for (final id in _mapMarkerIds) {
      _mapController!.deleteOverlay(NOverlayInfo(type: NOverlayType.marker, id: id));
    }
    _mapMarkerIds.clear();

    final posts = await _boardApiService.getMapLocationPosts(
      latitude: latitude,
      longitude: longitude,
      zoom: zoom,
    );

    // 같은 좌표끼리 그룹핑
    final Map<String, List<MapPost>> grouped = {};
    for (final post in posts) {
      final key = '${post.latitude.toStringAsFixed(3)},${post.longitude.toStringAsFixed(3)}';
      grouped.putIfAbsent(key, () => []).add(post);
    }

    for (final postsAtLocation in grouped.values) {
      // score 내림차순 정렬 → 맨 위 post가 마커 대표
      postsAtLocation.sort((a, b) => b.score.compareTo(a.score));
      final topPost = postsAtLocation.first;
      final position = NLatLng(topPost.latitude, topPost.longitude);

      NOverlayImage? icon;
      if (topPost.fileUrl.isNotEmpty) {
        try {
          final stream = await _imageService.getImageStream(topPost.fileUrl);
          final bytes = await _imageService.createMarkerImage(stream);
          icon = await NOverlayImage.fromByteArray(bytes);
        } catch (_) {
          continue; // 이미지 로드 실패 시 마커 표시 생략
        }
      }

      final marker = NMarker(
        id: topPost.id,
        position: position,
        icon: icon,
        size: const Size(45, 45),
        caption: NOverlayCaption(
          text: _truncateMarkerTitle(topPost.title),
          textSize: 12,
          color: Colors.black,
          haloColor: Colors.white,
        ),
        // subCaption: 추후 해시태그 정보로 변경 예정
      );

      marker.setGlobalZIndex(200000 + topPost.score.toInt());

      marker.setOnTapListener((_) {
        _focusNode.unfocus();
        setState(() {
          _searchResults = [];
          _selectedSymbol = null;
          _selectedPlace = null;
          _isLoadingPlace = false;
          _selectedPosts = postsAtLocation;
        });
      });

      if (!mounted) return;
      _mapController!.addOverlay(marker);
      _mapMarkerIds.add(topPost.id);
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
      _selectedPosts = [];
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

    // 초기화 시점은 버튼 표시 없이 기준값만 저장
    if (!_mapInitialized) {
      _mapInitialized = true;
      _lastQueriedTarget = currentTarget;
      _lastQueriedZoom = currentZoom;
      return;
    }

    final zoomChanged = (currentZoom - _lastQueriedZoom).abs() >= _zoomChangeTrigger;
    final positionChanged = _lastQueriedTarget == null ||
        currentTarget.latitude != _lastQueriedTarget!.latitude ||
        currentTarget.longitude != _lastQueriedTarget!.longitude;

    if (zoomChanged || positionChanged) {
      setState(() => _showNearbyButton = true);
    }
  }

  void _onNearbyButtonTap() async {
    if (_mapController == null) return;
    final camera = await _mapController!.getCameraPosition();
    setState(() {
      _showNearbyButton = false;
      _lastQueriedTarget = camera.target;
      _lastQueriedZoom = camera.zoom;
    });
    _loadMapMarkers(
      camera.target.latitude,
      camera.target.longitude,
      camera.zoom.round(),
    );
  }

  String _truncateMarkerTitle(String title) =>
      title.length > 10 ? '${title.substring(0, 10)}...' : title;

  void _closeAllCards() {
    setState(() {
      _selectedSymbol = null;
      _selectedPlace = null;
      _isLoadingPlace = false;
      _selectedPosts = [];
      _cardDragOffset = 0.0;
    });
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
              _loadMapMarkers(seoulCityHall.latitude, seoulCityHall.longitude, 14);
            },
            onMapTapped: (point, latLng) => _closeAllCards(),
            onSymbolTapped: _onSymbolTapped,
            onCameraIdle: _onCameraIdle,
          ),
          // 검색창
          Positioned(
            top: safeAreaPadding.top + 12,
            left: 16,
            right: 16,
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
          // 이 주변 스토리 조회 버튼
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            left: 0,
            right: 0,
            bottom: _showNearbyButton && !_isAnyCardOpen ? 52 : -60,
            child: Center(
              child: GestureDetector(
                onTap: _onNearbyButtonTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x44000000),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded, color: Color(0xFF1A1A2E), size: 16),
                      SizedBox(width: 6),
                      Text(
                        '이 주변 스토리 조회',
                        style: TextStyle(
                          color: Color(0xFF1A1A2E),
                          fontSize: 14,
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 공유하기 버튼
          Positioned(
            right: 16,
            bottom: _isAnyCardOpen ? 208 + 56 : 40 + 56,
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
            bottom: _isAnyCardOpen ? 208 : 40,
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
          // 커스텀 마커 탭 시 하단 게시글 카드
          AnimatedPositioned(
            duration: _cardDragOffset > 0
                ? Duration.zero
                : const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            left: 0,
            right: 0,
            bottom: _selectedPosts.isNotEmpty ? -_cardDragOffset : -260,
            child: _PostInfoCard(
              posts: _selectedPosts,
              safeAreaBottom: safeAreaPadding.bottom,
              onClose: _closeAllCards,
              onDragUpdate: _onCardDragUpdate,
              onDragEnd: _onCardDragEnd,
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

class _PostInfoCard extends StatefulWidget {
  final List<MapPost> posts;
  final double safeAreaBottom;
  final VoidCallback onClose;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;

  const _PostInfoCard({
    required this.posts,
    required this.safeAreaBottom,
    required this.onClose,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  State<_PostInfoCard> createState() => _PostInfoCardState();
}

class _PostInfoCardState extends State<_PostInfoCard> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(_PostInfoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 다른 마커 탭 시 첫 페이지로 리셋
    if (oldWidget.posts != widget.posts) {
      _currentPage = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.posts.isEmpty) return const SizedBox.shrink();

    final total = widget.posts.length;

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 핸들 바
          GestureDetector(
            onVerticalDragUpdate: widget.onDragUpdate,
            onVerticalDragEnd: widget.onDragEnd,
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
          // n/N 인디케이터 + 닫기 (여러 개일 때만)
          if (total > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
              child: Row(
                children: [
                  Row(
                    children: List.generate(total, (i) => Container(
                      width: i == _currentPage ? 16 : 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: i == _currentPage
                            ? const Color(0xFF4D91FF)
                            : const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    )),
                  ),
                  const Spacer(),
                  Text(
                    '${_currentPage + 1} / $total',
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'Pretendard',
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, color: Color(0xFF9E9E9E), size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          // 게시글 PageView
          SizedBox(
            height: 155 + widget.safeAreaBottom,
            child: PageView.builder(
              controller: _pageController,
              itemCount: total,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, index) {
                final post = widget.posts[index];
                return Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + widget.safeAreaBottom),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 제목 + 닫기 (단일일 때만 닫기 버튼 여기)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              post.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A2E),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (total == 1) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: widget.onClose,
                              icon: const Icon(Icons.close, color: Color(0xFF9E9E9E), size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      // 주소
                      if (post.streetName.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF9E9E9E)),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                post.streetName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Pretendard',
                                  color: Color(0xFF9E9E9E),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 4),
                      // 내용 (20자 제한)
                      if (post.content.isNotEmpty)
                        Text(
                          post.content.length > 20
                              ? '${post.content.substring(0, 20)}...'
                              : post.content,
                          style: const TextStyle(
                            fontSize: 13,
                            fontFamily: 'Pretendard',
                            color: Color(0xFF374151),
                          ),
                        ),
                      const Spacer(),
                      // 좋아요 · 댓글 · 자세히 보기
                      Row(
                        children: [
                          const Icon(Icons.favorite_outline, size: 15, color: Color(0xFFFF6B6B)),
                          const SizedBox(width: 4),
                          Text(
                            '${post.likeCount}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontFamily: 'Pretendard',
                              color: Color(0xFF9E9E9E),
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Icon(Icons.chat_bubble_outline, size: 15, color: Color(0xFF4D91FF)),
                          const SizedBox(width: 4),
                          Text(
                            '${post.replyCount}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontFamily: 'Pretendard',
                              color: Color(0xFF9E9E9E),
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => Get.toNamed('/detail-board', parameters: {'id': post.id}),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4D91FF),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '자세히 보기',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontFamily: 'Pretendard',
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.white),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

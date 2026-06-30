import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:get/get.dart';
import 'package:unimal/screens/map/bottom_card/relative_time.dart';
import 'package:unimal/screens/profile/mypage/post_detail_sheet.dart';
import 'package:unimal/service/board/board_api_service.dart';
import 'package:unimal/service/board/model/board_post.dart';
import 'package:unimal/service/image/image_service.dart';
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
  final _imageService = ImageService();
  final _authState = Get.find<AuthState>();

  NaverMapController? _mapController;
  bool _markersRendered = false;
  // 클러스터 빌더 재사용: 마커 id → 개별 아이콘(size==1 복원), 카운트 → 버블 아이콘.
  final Map<String, NOverlayImage> _markerIcons = {};
  final Map<int, NOverlayImage> _clusterBubbleCache = {};

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
    final results = await Future.wait([
      _boardApi.getMyPostList(sortType: 'LATEST'),
      _userInfoService.getMemberInfo(_authState.accessToken.value),
      _boardApi.getMyPostTotal(),
      _boardApi.getMyLikedTotal(),
    ]);
    if (mounted) {
      setState(() {
        _posts = results[0] as List<BoardPost>;
        _userInfo = results[1] as UserInfoModel?;
        _myTotal = (results[2] as int?) ?? (_posts.length);
        _likedTotal = results[3] as int;
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
              await _imageService.getImageStream(p.fileInfoList.first.fileUrl);
          final bytes = await _imageService.createMarkerImage(stream);
          icon = await NOverlayImage.fromByteArray(bytes);
        } else {
          final bytes = await _imageService.createTextDotImage();
          icon = await NOverlayImage.fromByteArray(bytes);
        }
      } catch (_) {
        continue; // 이미지 로드 실패한 마커는 건너뛴다(메인 지도와 동일).
      }

      final id = 'mystory_${p.boardId}';
      _markerIcons[id] = icon; // 클러스터 빌더 size==1 복원용
      final title = displayTitle(p.title, p.content);
      final marker = NClusterableMarker(
        id: id,
        position: jittered[p.boardId]!,
        icon: icon,
        size: const Size(32, 32),
        tags: {'title': title, 'boardId': p.boardId},
        caption: NOverlayCaption(
          text: _markerCaption(title),
          textSize: 13,
          color: colors.textPrimary,
          haloColor: colors.background,
        ),
      );
      // 클러스터링 비활성 줌(16+)에서 단일 마커 탭.
      marker.setOnTapListener((NClusterableMarker _) {
        if (mounted) showPostDetailSheet(context, p.boardId);
      });
      markers.add(marker);
    }
    if (!mounted) return;
    await controller.addOverlayAll(markers);
    await _fitCamera(
      controller,
      located.map((p) => jittered[p.boardId]!).toList(),
    );
  }

  String _markerCaption(String title) =>
      title.length > 12 ? '${title.substring(0, 12)}…' : title;

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
        clusterMarker.setSize(const Size(32, 32));
      }
      clusterMarker.setCaption(NOverlayCaption(
        text: _markerCaption((child?.tags['title'] ?? '').trim()),
        textSize: 13,
        color: colors.textPrimary,
        haloColor: colors.background,
      ));
      final boardId = child?.tags['boardId'];
      if (boardId != null) {
        clusterMarker.setOnTapListener((_) {
          if (mounted) showPostDetailSheet(context, boardId);
        });
      }
      return;
    }

    // 다중 — 카운트 버블.
    clusterMarker.setCaption(const NOverlayCaption(text: ''));
    final cached = _clusterBubbleCache[info.size];
    if (cached != null) {
      clusterMarker.setIcon(cached);
      clusterMarker.setSize(const Size(46, 46));
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
        final nextZoom = cam.zoom < 16 ? 16.0 : cam.zoom;
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
    final icon = await NOverlayImage.fromWidget(
      context: context,
      size: const Size(46, 46),
      widget: _ClusterBubble(count: count, color: colors.primary),
    );
    _clusterBubbleCache[count] = icon;
    clusterMarker.setIcon(icon);
    clusterMarker.setSize(const Size(46, 46));
  }

  // 진입 시 overview 줌 상한. 클러스터링은 줌 15까지 동작하므로(16+는 펼침)
  // 이 값 이하에서 시작해야 "이 지역 N개" 묶음이 보인다.
  static const double _maxFitZoom = 13.0;

  Future<void> _fitCamera(
      NaverMapController controller, List<NLatLng> points) async {
    if (points.length == 1) {
      await controller.updateCamera(
        NCameraUpdate.scrollAndZoomTo(target: points.first, zoom: _maxFitZoom),
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
      ),
    );
    // fitBounds가 너무 깊게 줌인하면 상한으로 당긴다.
    final cam = await controller.getCameraPosition();
    if (cam.zoom > _maxFitZoom) {
      await controller.updateCamera(
        NCameraUpdate.scrollAndZoomTo(target: cam.target, zoom: _maxFitZoom),
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
              consumeSymbolTapEvents: false,
            ),
            clusterOptions: NaverMapClusteringOptions(
              // 줌 15까지 묶고 16+ 부터 개별 마커로 펼침.
              enableZoomRange: const NInclusiveRange(0, 15),
              animationDuration: Duration.zero,
              mergeStrategy: const NClusterMergeStrategy(
                willMergedScreenDistance: {
                  NInclusiveRange(0, 12): 100.0,
                  NInclusiveRange(13, 14): 80.0,
                  NInclusiveRange(15, 15): 60.0,
                },
              ),
              clusterMarkerBuilder: _buildClusterMarker,
            ),
            onMapReady: _onMapReady,
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

  Widget _buildListRow(AppColors colors, BoardPost post) {
    final hasImage = post.fileInfoList.isNotEmpty;
    return GestureDetector(
      onTap: () => showPostDetailSheet(context, post.boardId),
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

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:get/get.dart';
import 'package:unimal/screens/map/bottom_card/relative_time.dart';
import 'package:unimal/screens/map/marker/story_dot_marker.dart';
import 'package:unimal/screens/secret_map/secret_map_screen.dart';
import 'package:unimal/screens/secret_map/widgets/secret_map_common.dart';
import 'package:unimal/service/secret_map/model/secret_map_info.dart';
import 'package:unimal/service/secret_map/secret_map_service.dart';
import 'package:unimal/theme/app_colors.dart';

/// 우리지도(구 비밀지도) 탭 뎁스 1 — 내 지도 리스트.
///
/// 스펙: docs/specs/2026-07-11-비밀지도-UX.md §3.1
/// - 카드형 리스트: 미니 지도 프리뷰 + 지도명 + 멤버 수 + 최근 활동
/// - 상단 액션: `+ 지도 만들기`, `초대 코드로 참여`
/// - 빈 상태 온보딩 + 새 글 뱃지
class SecretMapListScreen extends StatefulWidget {
  const SecretMapListScreen({super.key});

  @override
  State<SecretMapListScreen> createState() => SecretMapListScreenState();
}

class SecretMapListScreenState extends State<SecretMapListScreen> {
  final _service = SecretMapService();

  List<SecretMapInfo> _maps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMaps();
  }

  /// 루트 탭 재터치 시 새로고침 진입점 (root_screen 패턴).
  void refreshSecretMaps() => _loadMaps();

  Future<void> _loadMaps() async {
    setState(() => _isLoading = true);
    final maps = await _service.getMyMaps();
    if (!mounted) return;
    setState(() {
      _maps = maps;
      _isLoading = false;
    });
  }

  void _openMap(SecretMapInfo info) {
    Get.to(() => SecretMapScreen(info: info));
  }

  // ---------------------------------------------------------------------
  // 지도 만들기 / 초대 코드 참여
  // ---------------------------------------------------------------------

  Future<void> _showCreateSheet() async {
    final name = await _showTextInputSheet(
      title: '새 우리지도 만들기',
      hint: '지도 이름 (예: 러닝 크루 코스)',
      buttonLabel: '만들기',
    );
    if (name == null || name.trim().isEmpty) return;

    final created = await _service.createMap(name.trim());
    if (!mounted) return;
    setState(() => _maps = [created, ..._maps]);
    _openMap(created);
  }

  Future<void> _showJoinSheet() async {
    final code = await _showTextInputSheet(
      title: '초대 코드로 참여',
      hint: '초대 코드 입력',
      buttonLabel: '지도 찾기',
    );
    if (code == null || code.trim().isEmpty) return;

    final found = await _service.findMapByCode(code.trim());
    if (!mounted) return;
    if (found == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('초대 코드를 찾을 수 없어요.')),
      );
      return;
    }
    await _showJoinConfirmSheet(found);
  }

  /// 합류 확인 시트 — 지도명 · 멤버 수 · 방장 (스펙 §3.5).
  Future<void> _showJoinConfirmSheet(SecretMapInfo info) async {
    final colors = AppColors.of(context);
    final owner = info.members.where((m) => m.isOwner).toList();
    final ownerName = owner.isNotEmpty ? owner.first.nickname : '알 수 없음';

    final joined = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SecretMapSheetContainer(
        colors: colors,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.map_outlined, size: 40, color: colors.primaryStrong),
            const SizedBox(height: 12),
            Text(
              info.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                fontFamily: 'Pretendard',
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '멤버 ${info.memberCount} · 방장 $ownerName',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'Pretendard',
                color: colors.textTertiary,
              ),
            ),
            const SizedBox(height: 20),
            SecretMapPrimaryButton(
              colors: colors,
              label: '이 지도에 참여하기',
              onTap: () => Navigator.of(sheetContext).pop(true),
            ),
          ],
        ),
      ),
    );

    if (joined != true || !mounted) return;
    await _service.joinMap(info.id);
    if (!mounted) return;
    setState(() => _maps = [info, ..._maps]);
    _openMap(info);
  }

  Future<String?> _showTextInputSheet({
    required String title,
    required String hint,
    required String buttonLabel,
  }) {
    final colors = AppColors.of(context);
    final controller = TextEditingController();

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: SecretMapSheetContainer(
          colors: colors,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Pretendard',
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 30,
                style: TextStyle(
                  fontSize: 15,
                  fontFamily: 'Pretendard',
                  color: colors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                    fontSize: 15,
                    fontFamily: 'Pretendard',
                    color: colors.textMuted,
                  ),
                  counterText: '',
                  filled: true,
                  fillColor: colors.surfaceMuted,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (value) =>
                    Navigator.of(sheetContext).pop(value),
              ),
              const SizedBox(height: 16),
              SecretMapPrimaryButton(
                colors: colors,
                label: buttonLabel,
                onTap: () =>
                    Navigator.of(sheetContext).pop(controller.text),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(colors),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                          color: colors.primaryStrong))
                  : _maps.isEmpty
                      ? _buildEmptyState(colors)
                      : _buildMapList(colors),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '우리지도',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              fontFamily: 'Pretendard',
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '초대된 멤버끼리만 보는 우리들의 지도',
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Pretendard',
              color: colors.textTertiary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SecretMapPrimaryButton(
                  colors: colors,
                  label: '+ 지도 만들기',
                  onTap: _showCreateSheet,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SecretMapOutlineButton(
                  colors: colors,
                  label: '초대 코드로 참여',
                  onTap: _showJoinSheet,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMapList(AppColors colors) {
    return RefreshIndicator(
      color: colors.primaryStrong,
      onRefresh: _loadMaps,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _maps.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final info = _maps[index];
          return _SecretMapCard(
            info: info,
            onTap: () => _openMap(info),
          );
        },
      ),
    );
  }

  /// 빈 상태 — 지도 0개가 첫인상 (스펙 §3.1).
  Widget _buildEmptyState(AppColors colors) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.primaryWash,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.map_outlined,
                  size: 34, color: colors.primaryStrong),
            ),
            const SizedBox(height: 18),
            Text(
              '아직 우리지도가 없어요',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                fontFamily: 'Pretendard',
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '친구를 초대해 우리만의 지도를 가꿔보세요.\n길고양이 급식소 지도, 러닝 크루 코스,\n우리 가족 맛집 지도…',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                fontFamily: 'Pretendard',
                color: colors.textTertiary,
              ),
            ),
            const SizedBox(height: 24),
            SecretMapPrimaryButton(
              colors: colors,
              label: '+ 첫 지도 만들기',
              onTap: _showCreateSheet,
            ),
            const SizedBox(height: 10),
            SecretMapOutlineButton(
              colors: colors,
              label: '초대 코드로 참여',
              onTap: _showJoinSheet,
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------------
// 지도 카드 — 미니 지도 프리뷰 + 지도명 + 멤버 수 + 최근 활동 + 새 글 뱃지
// -------------------------------------------------------------------------

class _SecretMapCard extends StatelessWidget {
  final SecretMapInfo info;
  final VoidCallback onTap;

  const _SecretMapCard({required this.info, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final lastActivity = info.lastActivityAt != null
        ? relativeTimeFromString(info.lastActivityAt!)
        : '활동 없음';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 120,
              child: _MiniMapPreview(markers: info.markerPreview),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                info.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Pretendard',
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                            if (info.hasNewPost) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  '새 글',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Pretendard',
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '멤버 ${info.memberCount} · $lastActivity',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Pretendard',
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      size: 22, color: colors.textMuted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 미니 지도 프리뷰 — 마이페이지 간이 지도 패턴 재사용(사이즈 축소).
///
/// 서버가 내려주는 마커 좌표 목록으로 정적 렌더(인터랙션 없음).
/// lite 모드 + 제스처 off (MyStoryMapCard와 동일한 비용 절감 방침).
class _MiniMapPreview extends StatelessWidget {
  final List<SecretMapLatLng> markers;

  const _MiniMapPreview({required this.markers});

  Future<void> _onMapReady(
      BuildContext context, NaverMapController controller) async {
    if (markers.isEmpty) return;

    final icon = await buildStoryMarkerIcon(context, AppColors.of(context));

    final overlays = markers
        .asMap()
        .entries
        .map((e) => NMarker(
              id: 'preview_${e.key}',
              position: NLatLng(e.value.latitude, e.value.longitude),
              icon: icon,
              size: kStoryMarkerSize,
              anchor: const NPoint(0.5, 0.5),
            ))
        .toSet();
    await controller.addOverlayAll(overlays);

    if (markers.length == 1) {
      await controller.updateCamera(
        NCameraUpdate.scrollAndZoomTo(
          target: NLatLng(markers.first.latitude, markers.first.longitude),
          zoom: 13,
        ),
      );
      return;
    }

    final bounds = NLatLngBounds.from(
      markers.map((m) => NLatLng(m.latitude, m.longitude)).toList(),
    );
    await controller.updateCamera(
      NCameraUpdate.fitBounds(bounds, padding: const EdgeInsets.all(28)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    if (markers.isEmpty) {
      // 마커가 없으면 지도 뷰를 만들지 않는다 (뷰 생성 과금 절약).
      return Container(
        color: colors.surfaceVariant,
        alignment: Alignment.center,
        child: Text(
          '아직 스토리가 없어요',
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'Pretendard',
            color: colors.textMuted,
          ),
        ),
      );
    }
    return AbsorbPointer(
      child: NaverMap(
        options: NaverMapViewOptions(
          initialCameraPosition: NCameraPosition(
            target: NLatLng(markers.first.latitude, markers.first.longitude),
            zoom: 12,
          ),
          mapType: NMapType.basic,
          liteModeEnable: true,
          scrollGesturesEnable: false,
          zoomGesturesEnable: false,
          tiltGesturesEnable: false,
          rotationGesturesEnable: false,
          stopGesturesEnable: false,
          scaleBarEnable: false,
          logoClickEnable: false,
          consumeSymbolTapEvents: false,
        ),
        onMapReady: (controller) => _onMapReady(context, controller),
      ),
    );
  }
}

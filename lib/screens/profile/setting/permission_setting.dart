import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class PermissionSettingScreen extends StatefulWidget {
  const PermissionSettingScreen({super.key});

  @override
  State<PermissionSettingScreen> createState() => _PermissionSettingScreenState();
}

class _PermissionSettingScreenState extends State<PermissionSettingScreen> with WidgetsBindingObserver {
  static const Color _primary = Color(0xFF7AB3FF);

  // 위치/알림은 별도 상태로 관리
  bool? _locationGranted;
  bool? _notificationGranted;

  final List<_PermissionItem> _items = [
    _PermissionItem(
      permission: Permission.camera,
      icon: Icons.camera_alt_outlined,
      title: '카메라',
      description: '게시글 사진 촬영',
    ),
    _PermissionItem(
      permission: Permission.photos,
      icon: Icons.photo_library_outlined,
      title: '사진 라이브러리',
      description: '게시글에 사진 첨부',
    ),
  ];

  Map<Permission, PermissionStatus> _statuses = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStatuses();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadStatuses();
  }

  Future<void> _openAppPermissionSettings() async {
    final uri = Uri.parse('app-settings:');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await _openAppPermissionSettings();
    }
  }

  Future<void> _loadStatuses() async {
    if (mounted) setState(() => _isLoading = true);

    // 일반 권한 (카메라, 사진)
    final Map<Permission, PermissionStatus> result = {};
    for (final item in _items) {
      result[item.permission] = await item.permission.status;
    }

    // 위치 권한은 Geolocator로 체크 (whileInUse / always 모두 허용으로 처리)
    final locPerm = await Geolocator.checkPermission();
    final locGranted = locPerm == LocationPermission.whileInUse ||
        locPerm == LocationPermission.always;
    debugPrint('[PermissionSetting] 위치 권한 상태: $locPerm');

    // 알림 권한은 FirebaseMessaging으로 체크
    final notifSettings = await FirebaseMessaging.instance.getNotificationSettings();
    final notifGranted = notifSettings.authorizationStatus == AuthorizationStatus.authorized ||
        notifSettings.authorizationStatus == AuthorizationStatus.provisional;
    debugPrint('[PermissionSetting] 알림 권한 상태: ${notifSettings.authorizationStatus}');

    if (mounted) {
      setState(() {
        _statuses = result;
        _locationGranted = locGranted;
        _notificationGranted = notifGranted;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF374151), size: 20),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          '권한설정',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            fontFamily: 'Pretendard',
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 안내 배너
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: _primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '아래 권한들은 서비스 이용에 필요합니다.\n항목을 탭하면 기기 설정으로 이동합니다.',
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'Pretendard',
                      color: _primary.withOpacity(0.85),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 권한 리스트
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _primary))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: _items.length + 2, // +위치 +알림
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      // 첫 번째: 위치 (Geolocator)
                      if (index == 0) {
                        return _PermissionTile(
                          icon: Icons.location_on_outlined,
                          title: '위치',
                          description: '주변 게시글 및 지도 서비스 이용',
                          isGranted: _locationGranted,
                          onTap: () {
                            debugPrint('[PermissionSetting] 탭: 위치, 허용 여부: $_locationGranted');
                            _openAppPermissionSettings();
                          },
                        );
                      }
                      // 마지막: 알림 (FirebaseMessaging)
                      if (index == _items.length + 1) {
                        return _PermissionTile(
                          icon: Icons.notifications_outlined,
                          title: '알림',
                          description: '새 댓글, 좋아요 등 알림 수신',
                          isGranted: _notificationGranted,
                          onTap: () {
                            debugPrint('[PermissionSetting] 탭: 알림, 허용 여부: $_notificationGranted');
                            _openAppPermissionSettings();
                          },
                        );
                      }
                      // 중간: 카메라, 사진 (permission_handler)
                      final item = _items[index - 1];
                      final status = _statuses[item.permission];
                      return _PermissionTile(
                        icon: item.icon,
                        title: item.title,
                        description: item.description,
                        isGranted: status == PermissionStatus.granted || status == PermissionStatus.limited,
                        onTap: () {
                          debugPrint('[PermissionSetting] 탭: ${item.title}, 현재 상태: $status');
                          _openAppPermissionSettings();
                        },
                      );
                    },
                  ),
          ),
          // 설정으로 이동 버튼
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: GestureDetector(
              onTap: () => openAppSettings(),
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    '기기 설정에서 권한 변경',
                    style: TextStyle(
                      fontSize: 15,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool? isGranted;
  final VoidCallback onTap;

  static const Color _primary = Color(0xFF7AB3FF);

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.isGranted,
    required this.onTap,
  });

  String get _label {
    if (isGranted == null) return '확인 중';
    return isGranted! ? '허용' : '거부됨';
  }

  Color get _color {
    if (isGranted == true) return const Color(0xFF34C759);
    return const Color(0xFFFF3B30);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: _primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Pretendard',
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _label,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                      color: _color,
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
}

class _PermissionItem {
  final Permission permission;
  final IconData icon;
  final String title;
  final String description;

  const _PermissionItem({
    required this.permission,
    required this.icon,
    required this.title,
    required this.description,
  });
}

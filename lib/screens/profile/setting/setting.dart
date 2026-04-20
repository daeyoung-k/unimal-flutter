import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:unimal/screens/profile/setting/notice/notice_list.dart';
import 'package:unimal/screens/profile/setting/permission_setting.dart';

import 'package:unimal/screens/profile/setting/terms_of_service.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  String _version = '';
  bool _isCenterExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = 'v${info.version}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          '설정',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.black,
            fontFamily: 'Pretendard',
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          _buildItem(
            icon: Icons.campaign_outlined,
            title: '공지사항',
            onTap: () => Get.to(() => const NoticeListScreen()),
          ),
          _buildDivider(),
          _buildItem(
            icon: Icons.security_outlined,
            title: '권한설정',
            onTap: () => Get.to(() => const PermissionSettingScreen()),
          ),
          _buildDivider(),
          _buildItem(
            icon: Icons.info_outline,
            title: '버전정보',
            trailing: Text(
              _version,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black45,
                fontFamily: 'Pretendard',
              ),
            ),
            onTap: () {},
          ),
          const SizedBox(height: 8),
          _buildSectionDivider(),
          const SizedBox(height: 8),
          _buildItem(
            icon: Icons.description_outlined,
            title: '이용약관',
            onTap: () => Get.to(() => const TermsOfServiceScreen()),
          ),
          _buildDivider(),
          _buildExpandableItem(),
        ],
      ),
    );
  }

  Widget _buildExpandableItem() {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          leading: const Icon(Icons.headset_mic_outlined, color: Color(0xFF4D91FF), size: 22),
          title: const Text(
            '고객센터',
            style: TextStyle(fontSize: 15, color: Colors.black87, fontFamily: 'Pretendard'),
          ),
          trailing: Icon(
            _isCenterExpanded ? Icons.expand_less : Icons.expand_more,
            color: Colors.black26,
            size: 20,
          ),
          onTap: () => setState(() => _isCenterExpanded = !_isCenterExpanded),
        ),
        if (_isCenterExpanded) ...[
          _buildSubItem(
            icon: Icons.support_agent_outlined,
            title: '고객 지원',
            onTap: () => Get.toNamed('/webview', parameters: {'url': 'https://api.unimal.co.kr/stomap/support', 'title': '고객 지원'}),
          ),
          _buildSubItem(
            icon: Icons.lock_outline,
            title: '개인정보 처리방침',
            onTap: () => Get.toNamed('/webview', parameters: {'url': 'https://api.unimal.co.kr/stomap/privacy', 'title': '개인정보 처리방침'}),
          ),
          _buildSubItem(
            icon: Icons.manage_accounts_outlined,
            title: '계정 삭제 관리',
            onTap: () => Get.toNamed('/webview', parameters: {'url': 'https://api.unimal.co.kr/stomap/delete-account', 'title': '계정 삭제 관리'}),
            showDivider: false,
          ),
        ],
      ],
    );
  }

  Widget _buildSubItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        Divider(height: 1, indent: 56, endIndent: 20, color: Colors.grey[200]),
        ListTile(
          contentPadding: const EdgeInsets.only(left: 40, right: 20, top: 2, bottom: 2),
          leading: Icon(icon, color: const Color(0xFF4D91FF), size: 20),
          title: Text(
            title,
            style: const TextStyle(fontSize: 14, color: Colors.black54, fontFamily: 'Pretendard'),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.black26, size: 18),
          onTap: onTap,
        ),
      ],
    );
  }

  Widget _buildItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Icon(icon, color: const Color(0xFF4D91FF), size: 22),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          color: Colors.black87,
          fontFamily: 'Pretendard',
        ),
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.black26, size: 20),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 56,
      endIndent: 20,
      color: Colors.grey[200],
    );
  }

  Widget _buildSectionDivider() {
    return Container(height: 8, color: const Color(0xFFF5F5F5));
  }
}

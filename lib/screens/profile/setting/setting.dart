import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingScreen extends StatelessWidget {
  const SettingScreen({super.key});

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
            onTap: () {},
          ),
          _buildDivider(),
          _buildItem(
            icon: Icons.notifications_outlined,
            title: '알림설정',
            onTap: () {},
          ),
          _buildDivider(),
          _buildItem(
            icon: Icons.info_outline,
            title: '버전정보',
            trailing: const Text(
              'v1.0.0',
              style: TextStyle(
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
            onTap: () {},
          ),
          _buildDivider(),
          _buildItem(
            icon: Icons.lock_outline,
            title: '개인정보 취급방침',
            onTap: () {},
          ),
        ],
      ),
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

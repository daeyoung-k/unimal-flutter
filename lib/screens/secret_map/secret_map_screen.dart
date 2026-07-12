import 'package:flutter/material.dart';
import 'package:unimal/service/secret_map/model/secret_map_info.dart';
import 'package:unimal/theme/app_colors.dart';

/// 우리지도 뎁스 2 — 지도 화면 (마커 뷰 ⟷ 게시판 뷰).
///
/// 스펙: docs/specs/2026-07-11-비밀지도-UX.md §3.2 · 피그마 시안 06/07 참고.
/// 현재는 뼈대만 있는 스텁 — 서버 API 완성 후 아래 순서로 구현한다:
/// 1. 네이버 지도 + 마커 뷰 (공용 마커 시스템 `map/marker/` 재사용)
/// 2. 마커/게시판 뷰 토글 (담소 TALK · 공지 NOTICE, 공지 상단 고정)
/// 3. FAB 글쓰기 (스토리/담소 선택, 공지는 방장 전용)
/// 4. 앱바 멤버 아바타 스택 + 더보기(멤버 관리·초대·설정)
class SecretMapScreen extends StatelessWidget {
  final SecretMapInfo info;

  const SecretMapScreen({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: colors.textSecondary),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              info.name,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                fontFamily: 'Pretendard',
                color: colors.textPrimary,
              ),
            ),
            Text(
              '멤버 ${info.memberCount}',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'Pretendard',
                color: colors.textTertiary,
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 44, color: colors.primarySoft),
            const SizedBox(height: 14),
            Text(
              '지도 화면 준비 중이에요',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
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

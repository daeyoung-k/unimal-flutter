import 'package:flutter/material.dart';
import 'package:unimal/theme/app_colors.dart';

/// 우리지도(구 비밀지도) 화면 공용 위젯 — 버튼/바텀시트 컨테이너.

class SecretMapPrimaryButton extends StatelessWidget {
  final AppColors colors;
  final String label;
  final VoidCallback onTap;

  const SecretMapPrimaryButton({
    super.key,
    required this.colors,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFamily: 'Pretendard',
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class SecretMapOutlineButton extends StatelessWidget {
  final AppColors colors;
  final String label;
  final VoidCallback onTap;

  const SecretMapOutlineButton({
    super.key,
    required this.colors,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.borderStrong),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFamily: 'Pretendard',
            color: colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// 상단 그랩바 포함 바텀시트 컨테이너.
class SecretMapSheetContainer extends StatelessWidget {
  final AppColors colors;
  final Widget child;

  const SecretMapSheetContainer({
    super.key,
    required this.colors,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: colors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

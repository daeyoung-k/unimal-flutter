import 'package:flutter/material.dart';

/// 유니멀 디자인 토큰.
///
/// 사용처에서는 직접 `AppColors.light` / `AppColors.dark` 를 참조하거나,
/// 추후 ThemeData.extensions 로 등록해 `Theme.of(context).extension<AppColors>()`
/// 로 접근. 일단은 정적 두 인스턴스만 정의 — 사용처 치환은 점진적으로 진행.
///
/// 색 결정 원칙
/// - **시멘틱 명명**: 의미(역할) 기준. `primary`, `surface`, `textPrimary` 등.
///   같은 시멘틱이 light/dark에서 서로 다른 색이 되어도 의미는 유지됨.
/// - **다크 톤**: Material 3 / iOS 다크 가이드 절충.
///   브랜드 푸른색은 dark에서 약간 밝게 (대비 확보).
///   텍스트 단계는 light 의 미러 (가장 진한 ↔ 가장 옅은 반전).
class AppColors {
  // ────────────────────────────────────────────────────────────────
  // Brand — 푸른 톤
  // ────────────────────────────────────────────────────────────────

  /// 핀 마커, 클러스터 +N 뱃지, 강조 (가장 진한 브랜드).
  final Color primary;

  /// 글로우/활성 표시, 댓글 입력창 send 아이콘.
  final Color primaryStrong;

  /// 보조, 그라데이션 라이트 사이드, _primary 로 흩어져 있는 약한 톤.
  final Color primarySoft;

  /// 선택 배경, 답글 인디케이터, 카드 내부 강조 배경.
  final Color primaryWash;

  // ────────────────────────────────────────────────────────────────
  // Surface — 배경 / 카드 / 컨테이너
  // ────────────────────────────────────────────────────────────────

  /// 화면 전체 배경.
  final Color background;

  /// 카드, 바텀시트, 다이얼로그 표면.
  final Color surface;

  /// 텍스트 포스트, 비활성 슬롯, edit field 등 약한 표면.
  final Color surfaceVariant;

  /// 입력창 배경, 스크롤바, 가장 옅은 표면.
  final Color surfaceMuted;

  // ────────────────────────────────────────────────────────────────
  // Text — 단계
  // ────────────────────────────────────────────────────────────────

  /// 본문 텍스트, 제목.
  final Color textPrimary;

  /// 보조 본문, 카드 본문, 닉네임 강조.
  final Color textSecondary;

  /// 보조 텍스트, 메타데이터, 라벨.
  final Color textTertiary;

  /// 비활성 텍스트, 힌트, 가장 옅은 텍스트.
  final Color textMuted;

  // ────────────────────────────────────────────────────────────────
  // Border / Divider
  // ────────────────────────────────────────────────────────────────

  /// 일반 경계선, 입력창 외곽.
  final Color border;

  /// 강한 경계선 (선택 강조, 진한 구분).
  final Color borderStrong;

  /// 영역 구분 가로선.
  final Color divider;

  // ────────────────────────────────────────────────────────────────
  // Semantic — 의미 색
  // ────────────────────────────────────────────────────────────────

  /// 삭제, 위험, 오류.
  final Color danger;

  /// 텍스트 포스트, 강조 액센트.
  final Color accent;

  // ────────────────────────────────────────────────────────────────
  // External — 외부 브랜드 (다크모드에서도 고정)
  // ────────────────────────────────────────────────────────────────

  /// 카카오 로그인 노란색.
  final Color kakao;

  // ────────────────────────────────────────────────────────────────
  // Effect — 그림자
  // ────────────────────────────────────────────────────────────────

  /// 카드, 떠 있는 요소 그림자.
  final Color shadow;

  const AppColors({
    required this.primary,
    required this.primaryStrong,
    required this.primarySoft,
    required this.primaryWash,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.surfaceMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textMuted,
    required this.border,
    required this.borderStrong,
    required this.divider,
    required this.danger,
    required this.accent,
    required this.kakao,
    required this.shadow,
  });

  /// 현재 컨텍스트의 시스템 밝기에 따라 light/dark 인스턴스를 반환.
  /// MaterialApp.themeMode 설정과 무관하게 OS 다크모드를 자동 추적.
  /// 추후 ThemeData 정식 통합 시 이 of() 구현만 교체하면 사용처는 그대로.
  static AppColors of(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    return brightness == Brightness.dark ? dark : light;
  }

  /// 라이트 모드 컬러 세트.
  static const AppColors light = AppColors(
    // Brand
    primary: Color(0xFF3578E5),
    primaryStrong: Color(0xFF4D91FF),
    primarySoft: Color(0xFF7AB3FF),
    primaryWash: Color(0xFFEEF6FF),

    // Surface
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF5F5F5),
    surfaceMuted: Color(0xFFF3F4F6),

    // Text
    textPrimary: Color(0xFF1A1A2E),
    textSecondary: Color(0xFF374151),
    textTertiary: Color(0xFF6B7280),
    textMuted: Color(0xFF9CA3AF),

    // Border
    border: Color(0xFFE5E7EB),
    borderStrong: Color(0xFFB8BFC8),
    divider: Color(0xFFDDDDDD),

    // Semantic
    danger: Color(0xFFE53935),
    accent: Color(0xFFFF9F43),

    // External
    kakao: Color(0xFFFEE500),

    // Effect
    shadow: Color(0x22000000),
  );

  /// 다크 모드 컬러 세트.
  static const AppColors dark = AppColors(
    // Brand — dark 에서 살짝 밝게 (대비 확보)
    primary: Color(0xFF5B9FEF),
    primaryStrong: Color(0xFF7AB3FF),
    primarySoft: Color(0xFFA8CCFF),
    primaryWash: Color(0xFF1F2D45),

    // Surface — 단계적으로 진한 회색
    background: Color(0xFF0F1014),
    surface: Color(0xFF1C1D23),
    surfaceVariant: Color(0xFF2A2C33),
    surfaceMuted: Color(0xFF232529),

    // Text — light 의 미러 (가장 진한 ↔ 가장 옅은 반전)
    textPrimary: Color(0xFFF5F7FA),
    textSecondary: Color(0xFFD1D5DB),
    textTertiary: Color(0xFF9CA3AF),
    textMuted: Color(0xFF6B7280),

    // Border — 어두운 회색
    border: Color(0xFF2D2F36),
    borderStrong: Color(0xFF4A4D55),
    divider: Color(0xFF2D2F36),

    // Semantic — dark 에서 살짝 밝게
    danger: Color(0xFFFF6B6B),
    accent: Color(0xFFFFB872),

    // External — 카카오 노란색 고정
    kakao: Color(0xFFFEE500),

    // Effect — 더 진하게 (어두운 배경에서 그림자 가시성)
    shadow: Color(0x66000000),
  );
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:unimal/theme/app_colors.dart';

class CustomAlert {
  void showTextAlert(String title, String content) async {
    Get.dialog(AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          child: Text("확인"),
          onPressed: () {
            Get.back();
          },
        ),
      ],
    ));
  }

  /// [barrierDismissible] false 면 바깥 탭으로 닫을 수 없다 —
  /// 세션 만료 안내처럼 "확인 → 이동"이 반드시 실행돼야 하는 경우에 사용.
  void pageMovingWithshowTextAlert(
    String title,
    String content,
    String page, {
    bool barrierDismissible = true,
  }) {
    Get.dialog(
      AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            child: Text("확인"),
            onPressed: () {
              Get.offAllNamed(page);
            },
          ),
        ],
      ),
      barrierDismissible: barrierDismissible,
    );
  }

  // 경고창 확인 후 현재 페이지만 제거하고 지정된 페이지로 이동
  void showTextAlertAndNavigate(String title, String content, String page) {
    Get.dialog(AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          child: Text("확인"),
          onPressed: () {
            Get.back(); // 다이얼로그 닫기
            Get.offNamed(page); // 현재 페이지 제거하고 지정된 페이지로 이동
          },
        ),
      ],
    ));
  }

  /// 결과 안내 스낵바.
  ///
  /// `Get.snackbar` 를 쓰지 않는 이유 — GetX 스낵바는 앱 최상위 오버레이에
  /// 화면 맨 아래로 붙어서 **키보드가 올라와 있으면 키보드 뒤에 깔려 안 보인다.**
  /// 저장 버튼은 입력 직후에 누르는 버튼이라 사실상 항상 그 상황이고, 실제로
  /// "저장됐다는 표시가 없어 계속 누르게 된다"는 피드백이 나왔다.
  /// [ScaffoldMessenger] 는 `resizeToAvoidBottomInset` 으로 줄어든 Scaffold 안에
  /// 그려지므로 키보드 위에 뜬다.
  void showSnackBar(BuildContext context, String message,
      {bool isError = true}) {
    final colors = AppColors.of(context);
    ScaffoldMessenger.of(context)
      // 연타로 스낵바가 쌓이면 마지막 것만 늦게 보인다 — 항상 최신 것만 남긴다.
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? colors.danger : colors.accentGreen,
          duration: const Duration(seconds: 2),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          content: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: colors.onPrimary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: colors.onPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Pretendard',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}

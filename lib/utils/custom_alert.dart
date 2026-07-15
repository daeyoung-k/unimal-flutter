import 'package:flutter/material.dart';
import 'package:get/get.dart';

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

  void showSnackBar(BuildContext context, String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Center(
          child: Text(
            message,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }
}

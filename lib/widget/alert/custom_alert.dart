
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CustomAlert {

  void showTextAlert(
    String title, 
    String content
    ) async {
    Get.dialog(
      AlertDialog(
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
      )
    );
  }

  void pageMovingWithshowTextAlert(String title, String content, String page) {
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
      )
    );
  }
}
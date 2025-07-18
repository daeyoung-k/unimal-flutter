import 'package:flutter/material.dart';

class ManualButtonWidget extends StatelessWidget {
  final VoidCallback onPressed;
  
  const ManualButtonWidget({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: const Text(
        '이메일로 로그인',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontFamily: 'Pretendard',
        ),
      ),
    );
  }
}
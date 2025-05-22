
import 'package:flutter/material.dart';

class ActionIconButton extends StatelessWidget {
  final IconData icon;
  final String count;
  final VoidCallback? onTap;

  const ActionIconButton({
    super.key,
    required this.icon,
    required this.count,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 2),
          Text(count),
        ],
      ),
    );
  }
}
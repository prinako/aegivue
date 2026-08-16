import 'package:flutter/material.dart';

class AppLogoWidget extends StatelessWidget {
  final Widget logoIcon;
  const AppLogoWidget({super.key, required this.logoIcon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        // gradient: const LinearGradient(
        //   colors: [Color(0xFF7D89FF), Color(0xFF5260DC)],
        // ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: logoIcon,
    );
  }
}

import 'package:flutter/material.dart';

class AppLogoWidget extends StatelessWidget {
  const AppLogoWidget({super.key, required this.logoIcon});

  final Widget logoIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: logoIcon,
    );
  }
}

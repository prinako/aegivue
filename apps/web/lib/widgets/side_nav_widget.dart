import 'package:aegivue/widgets/app_logo_widget.dart';
import 'package:aegivue/widgets/nav_button_widget.dart';
import 'package:flutter/material.dart';

class SideNavWidget extends StatelessWidget {
  const SideNavWidget({
    super.key,
    required this.section,
    required this.onSelect,
  });

  final int section;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      color: const Color(0xFF0D1016),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 18, 22),
            child: Row(
              children: [
                AppLogoWidget(logoIcon: Image.asset('aegivue-logo.png')),
                SizedBox(width: 11),
                Text(
                  'Aegivue',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          NavButtonWidget(
            icon: Icons.grid_view_rounded,
            label: 'Overview',
            selected: section == 0,
            onTap: () => onSelect(0),
          ),
          NavButtonWidget(
            icon: Icons.video_library_outlined,
            label: 'Recordings',
            selected: section == 1,
            onTap: () => onSelect(1),
          ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, size: 17, color: Colors.white38),
                SizedBox(width: 8),
                Text(
                  'Self-hosted & private',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

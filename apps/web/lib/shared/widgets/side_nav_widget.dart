import 'package:aegivue/core/theme/app_colors.dart';
import 'package:aegivue/shared/widgets/app_logo_widget.dart';
import 'package:aegivue/shared/widgets/nav_button_widget.dart';
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
      color: AppColors.recessedSurface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 18, 22),
            child: Row(
              children: [
                AppLogoWidget(logoIcon: Image.asset('assets/aegivue-logo.png')),
                const SizedBox(width: 11),
                const Text(
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
            icon: Icons.live_tv_rounded,
            label: 'Live view',
            selected: section == 1,
            onTap: () => onSelect(1),
          ),
          NavButtonWidget(
            icon: Icons.video_library_outlined,
            label: 'Recordings',
            selected: section == 2,
            onTap: () => onSelect(2),
          ),
          NavButtonWidget(
            icon: Icons.motion_photos_on_outlined,
            label: 'Motion events',
            selected: section == 3,
            onTap: () => onSelect(3),
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

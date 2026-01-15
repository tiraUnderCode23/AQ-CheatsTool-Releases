import 'package:flutter/material.dart';
import '../hdd_guide/hdd_guide_tab.dart';
import '../image_retrofit/image_retrofit_tab.dart';

/// NBT Evo Combined Tab - Contains HDD Guide and Image Retrofit
class NbtEvoTab extends StatefulWidget {
  const NbtEvoTab({super.key});

  @override
  State<NbtEvoTab> createState() => _NbtEvoTabState();
}

class _NbtEvoTabState extends State<NbtEvoTab> with TickerProviderStateMixin {
  late TabController _subTabController;

  final List<_SubTabItem> _subTabs = [
    _SubTabItem(
      icon: Icons.storage_rounded,
      label: 'NBT EVO HDD',
      color: const Color(0xFFf97316), // Orange
    ),
    _SubTabItem(
      icon: Icons.image_rounded,
      label: 'Image Retrofit',
      color: const Color(0xFF8b5cf6), // Purple
    ),
  ];

  @override
  void initState() {
    super.initState();
    _subTabController = TabController(length: _subTabs.length, vsync: this);
  }

  @override
  void dispose() {
    _subTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sub Tab Bar
        _buildSubTabBar(),
        
        // Sub Tab Content
        Expanded(
          child: TabBarView(
            controller: _subTabController,
            physics: const BouncingScrollPhysics(),
            children: const [
              HDDGuideTab(), // NBT EVO HDD Guide
              ImageRetrofitTab(), // Image Retrofit
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: TabBar(
        controller: _subTabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [
              _subTabs[_subTabController.index].color.withValues(alpha: 0.8),
              _subTabs[_subTabController.index].color.withValues(alpha: 0.5),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: _subTabs[_subTabController.index].color.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(4),
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        onTap: (index) {
          setState(() {});
        },
        tabs: _subTabs.map((tab) {
          final isSelected = _subTabs.indexOf(tab) == _subTabController.index;
          return Tab(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    tab.icon,
                    size: 18,
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 8),
                  Text(tab.label),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SubTabItem {
  final IconData icon;
  final String label;
  final Color color;

  _SubTabItem({
    required this.icon,
    required this.label,
    required this.color,
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class CollapsibleSidebar extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;

  const CollapsibleSidebar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.isCollapsed,
    required this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const tealColor = Color(0xFF01565B);
    const goldColor = Color(0xFFDFBA6B);
    final dividerColor = const Color(0xFFE5DEC9);

    final userName = 'Swastik Jewels';
    final userInitial = 'S';
    final photoUrl = '';

    final sidebarWidth = isCollapsed ? 72.0 : 232.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: sidebarWidth,
      height: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFAF6EE), // exact beige/cream background
        border: Border(right: BorderSide(color: dividerColor, width: 1.5)),
      ),
      child: SafeArea(
        child: ClipRect(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: SizedBox(
              width: isCollapsed ? 72.0 : 232.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Section - User Profile (Avatar & Business Name)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    child: isCollapsed
                        ? Column(
                            children: [
                              _buildAvatar(
                                photoUrl,
                                userInitial,
                                goldColor,
                                tealColor,
                              ),
                              const SizedBox(height: 12),
                              const Divider(
                                color: Color(0xFFE5DEC9),
                                height: 1,
                                thickness: 1,
                              ),
                              const SizedBox(height: 12),
                              _buildToggleButton(
                                isCollapsed,
                                onToggleCollapse,
                                tealColor,
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              _buildAvatar(
                                photoUrl,
                                userInitial,
                                goldColor,
                                tealColor,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  userName,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF735C0F), // Olive gold text
                                    letterSpacing: 0.3,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildToggleButton(
                                isCollapsed,
                                onToggleCollapse,
                                tealColor,
                              ),
                            ],
                          ),
                  ),
                  const Divider(color: Color(0xFFE5DEC9), height: 1, thickness: 1),
                  const SizedBox(height: 16),

                  // Navigation Items (Home, Entry, Ledger, Reminders)
                  Expanded(
                    child: ListView(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      children: [
                        _SidebarItem(
                          icon: Icons.home,
                          label: 'Home',
                          isSelected: currentIndex == 0,
                          isCollapsed: isCollapsed,
                          onTap: () => onTap(0),
                        ),
                        const SizedBox(height: 8),
                        _SidebarItem(
                          icon: Icons.add_circle_outline_rounded,
                          label: 'Entry',
                          isSelected: currentIndex == 1,
                          isCollapsed: isCollapsed,
                          onTap: () => onTap(1),
                        ),
                        const SizedBox(height: 8),
                        _SidebarItem(
                          icon: Icons.note_alt_outlined,
                          label: 'Ledger',
                          isSelected: currentIndex == 2,
                          isCollapsed: isCollapsed,
                          onTap: () => onTap(2),
                        ),
                        const SizedBox(height: 8),
                        _SidebarItem(
                          icon: Icons.notifications_none_rounded,
                          label: 'Reminders',
                          isSelected: currentIndex == 3,
                          isCollapsed: isCollapsed,
                          onTap: () => onTap(3),
                        ),
                      ],
                    ),
                  ),

                  // Divider above Settings
                  const Divider(color: Color(0xFFE5DEC9), height: 1, thickness: 1),

                  // Settings Item
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: _SidebarItem(
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      isSelected: currentIndex == 4,
                      isCollapsed: isCollapsed,
                      onTap: () => onTap(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(
    String photoUrl,
    String initial,
    Color goldColor,
    Color tealColor,
  ) {
    return Container(
      width: 52,
      height: 52,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFDFBA6B), // Gold border ring
      ),
      padding: const EdgeInsets.all(2.5), // Gold outline thickness
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        padding: const EdgeInsets.all(1.5), // Space between ring and image
        child: Container(
          decoration: const BoxDecoration(shape: BoxShape.circle),
          clipBehavior: Clip.antiAlias,
          child: photoUrl.isNotEmpty
              ? Image.network(
                  photoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildInitialAvatar(initial, tealColor, goldColor),
                )
              : _buildInitialAvatar(initial, tealColor, goldColor),
        ),
      ),
    );
  }

  Widget _buildInitialAvatar(String initial, Color tealColor, Color goldColor) {
    return Container(
      color: tealColor,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.montserrat(
          color: const Color(0xFFFAF6EE),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildToggleButton(
    bool collapsed,
    VoidCallback onTap,
    Color tealColor,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: tealColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(
          collapsed ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
          color: tealColor,
          size: 20,
        ),
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isCollapsed;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isCollapsed,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    const tealColor = Color(0xFF01565B);
    const goldColor = Color(0xFFDFBA6B); // Mustard/gold background
    const borderTealColor = Color(0xFF01565B);
    const inactiveTextColor = Color(0xFF5E543F); // Dark grey/brown

    Widget content;

    if (widget.isCollapsed) {
      content = Container(
        width: 48,
        height: 40,
        decoration: widget.isSelected
            ? BoxDecoration(
                color: goldColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderTealColor, width: 1.5),
              )
            : null,
        alignment: Alignment.center,
        child: Icon(
          widget.icon,
          color: widget.isSelected ? borderTealColor : inactiveTextColor,
          size: 22,
        ),
      );
    } else {
      content = Container(
        height: 48,
        decoration: widget.isSelected
            ? BoxDecoration(
                color: goldColor,
                borderRadius: BorderRadius.circular(
                  10,
                ), // Slightly rounder for softer feel
                border: Border.all(color: borderTealColor, width: 1.5),
              )
            : BoxDecoration(
                color: _isHovered
                    ? tealColor.withOpacity(0.04)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(
              widget.icon,
              color: widget.isSelected ? borderTealColor : inactiveTextColor,
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                widget.label,
                style: GoogleFonts.montserrat(
                  fontSize: 15,
                  fontWeight: widget.isSelected
                      ? FontWeight.bold
                      : FontWeight.w600, // Stronger weight
                  color: widget.isSelected
                      ? borderTealColor
                      : inactiveTextColor,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: InkWell(
        onTap: widget.onTap,
        onHover: (hovered) {
          setState(() {
            _isHovered = hovered;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: content,
      ),
    );
  }
}

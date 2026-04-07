import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/layout_state.dart';

final pageSearchQueryProvider = NotifierProvider<SearchNotifier, String>(() {
  return SearchNotifier();
});

class SearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void update(String s) => state = s;
}

// ─────────────────────────────────────────────────────────────────────────────
// SIDEBAR — Permanent vertical navigation panel
// ─────────────────────────────────────────────────────────────────────────────

class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pagesAsync = ref.watch(pagesProvider);
    final currentIndex = ref.watch(currentPageIndexProvider);
    final searchQuery = ref.watch(pageSearchQueryProvider).toLowerCase();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? const Color(0xFF0D1321) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final primary = Theme.of(context).primaryColor;

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: bg,
        border: Border(right: BorderSide(color: borderColor, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── LOGO HEADER ────────────────────────────────────────────────────
          _SidebarHeader(isDark: isDark, primary: primary),

          // ── SEARCH ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: _SearchField(isDark: isDark, primary: primary),
          ),

          // ── SECTION LABEL ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Text(
              'DISPLAYS',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ),

          // ── PAGE LIST ──────────────────────────────────────────────────────
          Expanded(
            child: pagesAsync.when(
              data: (allPages) {
                final filtered = allPages
                    .where((p) => p.name.toLowerCase().contains(searchQuery))
                    .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      'No matches',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white30 : Colors.black26,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final page = filtered[index];
                    final realIndex = allPages.indexWhere((p) => p.id == page.id);
                    final isSelected = realIndex == currentIndex;

                    return _PageTile(
                      name: page.name,
                      isSelected: isSelected,
                      isDark: isDark,
                      primary: primary,
                      onTap: () {
                        ref.read(currentPageIndexProvider.notifier).value = realIndex;
                      },
                      onDelete: allPages.length > 1
                          ? () => _showDeleteConfirm(context, ref, page.id, page.name)
                          : null,
                    );
                  },
                );
              },
              loading: () => const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (err, _) => Center(
                child: Text(
                  'Error loading',
                  style: TextStyle(color: Colors.redAccent, fontSize: 11),
                ),
              ),
            ),
          ),

          // ── ADD DASHBOARD ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: _AddDashboardBtn(isDark: isDark, primary: primary, ref: ref),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, WidgetRef ref, String id, String name) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0D1321) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Display',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        content: Text(
          'Are you sure you want to delete "$name"? This action cannot be undone.',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              // If we are deleting the current page, switch to another first
              final currentIndex = ref.read(currentPageIndexProvider);
              final pagesAsync = ref.read(pagesProvider);
              final allPages = pagesAsync.value ?? [];
              final pageIndex = allPages.indexWhere((p) => p.id == id);
              
              if (currentIndex == pageIndex) {
                 ref.read(currentPageIndexProvider.notifier).value = 0;
              }

              ref.read(pagesProvider.notifier).deletePage(id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUB-COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class _SidebarHeader extends StatelessWidget {
  final bool isDark;
  final Color primary;
  const _SidebarHeader({required this.isDark, required this.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Row(
        children: [
          // ICON BADGE
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primary, primary.withAlpha(160)],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: primary.withAlpha(120),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.hub_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PDS PRO',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Text(
                'GROUND CONTROL',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                  color: primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchField extends ConsumerWidget {
  final bool isDark;
  final Color primary;
  const _SearchField({required this.isDark, required this.primary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fieldBg = isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return TextField(
      onChanged: (val) => ref.read(pageSearchQueryProvider.notifier).update(val),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : const Color(0xFF0F172A),
      ),
      decoration: InputDecoration(
        hintText: 'Search displays...',
        prefixIcon: Icon(Icons.search_rounded, size: 16, color: isDark ? Colors.white38 : Colors.black38),
        isDense: true,
        filled: true,
        fillColor: fieldBg,
        hintStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white30 : Colors.black26,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
    );
  }
}

class _PageTile extends StatefulWidget {
  final String name;
  final bool isSelected;
  final bool isDark;
  final Color primary;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _PageTile({
    required this.name,
    required this.isSelected,
    required this.isDark,
    required this.primary,
    required this.onTap,
    this.onDelete,
  });

  @override
  State<_PageTile> createState() => _PageTileState();
}

class _PageTileState extends State<_PageTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isSelected
        ? widget.primary.withAlpha(widget.isDark ? 30 : 20)
        : _hovered
            ? (widget.isDark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(5))
            : Colors.transparent;

    final textColor = widget.isSelected
        ? widget.primary
        : (widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B));

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.isSelected
                  ? widget.primary.withAlpha(widget.isDark ? 60 : 40)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.isSelected ? Icons.grid_view_rounded : Icons.grid_view_outlined,
                size: 15,
                color: textColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.name,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: widget.isSelected
                        ? widget.primary
                        : (widget.isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                    letterSpacing: 0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.isSelected && !_hovered)
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: widget.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.primary.withAlpha(180),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              if (widget.onDelete != null && _hovered)
                GestureDetector(
                  onTap: () {
                    // Prevent tile selection when clicking delete
                    widget.onDelete!();
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: widget.isSelected ? widget.primary : (widget.isDark ? Colors.white38 : Colors.black38),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddDashboardBtn extends StatefulWidget {
  final bool isDark;
  final Color primary;
  final WidgetRef ref;

  const _AddDashboardBtn({required this.isDark, required this.primary, required this.ref});

  @override
  State<_AddDashboardBtn> createState() => _AddDashboardBtnState();
}

class _AddDashboardBtnState extends State<_AddDashboardBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final hoverBg = widget.isDark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(4);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => _showAddPageDialog(context, widget.ref),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
          decoration: BoxDecoration(
            color: _hovered ? hoverBg : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            children: [
              Icon(Icons.add_rounded, size: 16, color: widget.isDark ? Colors.white54 : Colors.black45),
              const SizedBox(width: 10),
              Text(
                'New Display',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddPageDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0D1321) : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New Display',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Create a new telemetry display page',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: isDark ? Colors.white38 : Colors.black38),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: 'e.g. Power Subsystem',
            hintStyle: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white30 : Colors.black26,
              fontWeight: FontWeight.w400,
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref.read(pagesProvider.notifier).addPage(controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Create', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

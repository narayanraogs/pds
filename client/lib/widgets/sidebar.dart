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

class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pagesAsync = ref.watch(pagesProvider);
    final currentIndex = ref.watch(currentPageIndexProvider);
    final searchQuery = ref.watch(pageSearchQueryProvider).toLowerCase();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;


    final bg = isDark ? const Color(0xFF0D1321) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: bg,
        border: Border(right: BorderSide(color: borderColor, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SidebarHeader(isDark: isDark, primary: primary),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: _SearchField(isDark: isDark, primary: primary),
          ),

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
          Expanded(
            child: pagesAsync.when(
              data: (allPages) {
                final filtered = allPages.where((p) => p.name.toLowerCase().contains(searchQuery)).toList();
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final page = filtered[index];
                    final realIndex = allPages.indexWhere((p) => p.id == page.id);
                    return _PageTile(
                      name: page.name,
                      isSelected: realIndex == currentIndex,
                      isDark: isDark,
                      primary: primary,
                      onTap: () {
                        ref.read(currentPageIndexProvider.notifier).value = realIndex;
                      },
                      onDelete: allPages.length > 1 ? () => _showDeleteConfirm(context, ref, page.id, page.name) : null,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => const Center(child: Icon(Icons.error_outline)),
            ),
          ),
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
        title: Text('Delete Display', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        content: Text('Delete "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              ref.read(pagesProvider.notifier).deletePage(id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _SidebarHeader extends ConsumerWidget {
  final bool isDark;
  final Color primary;
  const _SidebarHeader({required this.isDark, required this.primary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [primary, primary.withAlpha(160)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.hub_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PDS PRO', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                  Text('GROUND CONTROL', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: primary)),
                ],
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
    return TextField(
      onChanged: (val) => ref.read(pageSearchQueryProvider.notifier).update(val),
      style: const TextStyle(fontSize: 12),
      decoration: InputDecoration(
        hintText: 'Search...',
        prefixIcon: const Icon(Icons.search_rounded, size: 16),
        isDense: true,
        filled: true,
        fillColor: isDark ? Colors.white.withAlpha(5) : Colors.black.withAlpha(5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
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
    final textColor = widget.isSelected ? widget.primary : (widget.isDark ? Colors.white70 : Colors.black54);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected ? widget.primary.withAlpha(20) : (_hovered ? Colors.white.withAlpha(5) : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.grid_view_outlined, size: 15, color: textColor),
              const SizedBox(width: 10),
              Expanded(child: Text(widget.name, style: TextStyle(fontSize: 12.5, fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500, color: textColor))),
              if (widget.onDelete != null && _hovered)
                IconButton(icon: const Icon(Icons.delete_outline, size: 16), onPressed: widget.onDelete, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddDashboardBtn extends StatelessWidget {
  final bool isDark;
  final Color primary;
  final WidgetRef ref;
  const _AddDashboardBtn({required this.isDark, required this.primary, required this.ref});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _showAddDialog(context),
      icon: const Icon(Icons.add, size: 16),
      label: const Text('New Display'),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 40),
        backgroundColor: Colors.transparent,
        foregroundColor: primary,
        elevation: 0,
        side: BorderSide(color: primary.withAlpha(50)),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Display'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              ref.read(pagesProvider.notifier).addPage(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}


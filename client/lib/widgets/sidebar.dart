import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/layout_state.dart';

// REPLACING StateProvider with a more robust Notifier for search
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
    final searchQueryArr = ref.watch(pageSearchQueryProvider).toLowerCase();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor.withAlpha(30))
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.hub_rounded, color: Colors.blueAccent, size: 24),
                    ),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PDS PRO',
                          style: TextStyle(
                            fontSize: 18, 
                            fontWeight: FontWeight.w900, 
                            letterSpacing: 2,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const Text(
                          'GROUND CONTROL',
                          style: TextStyle(
                            fontSize: 9, 
                            color: Colors.blueAccent, 
                            fontWeight: FontWeight.w900, 
                            letterSpacing: 1.5
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: TextField(
              onChanged: (val) => ref.read(pageSearchQueryProvider.notifier).update(val),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: 'FILTER DASHBOARDS...',
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Colors.blueAccent),
                isDense: true,
                filled: true,
                fillColor: Theme.of(context).cardColor,
                hintStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isDark ? Colors.white54 : Colors.black38, letterSpacing: 1),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
            child: Row(
              children: [
                Text(
                  'OPERATIONAL DISPLAYS', 
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54, 
                    fontSize: 9, 
                    fontWeight: FontWeight.w900, 
                    letterSpacing: 1.5
                  )
                ),
                const Spacer(),
                Icon(Icons.monitor_rounded, size: 12, color: isDark ? Colors.white70 : Colors.black54),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: pagesAsync.when(
              data: (allPages) {
                final filtered = allPages.where((p) => p.name.toLowerCase().contains(searchQueryArr)).toList();
                
                if (filtered.isEmpty) {
                  return const Center(child: Text('NO DISPLAYS MATCH', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final page = filtered[index];
                    final realIndex = allPages.indexWhere((p) => p.id == page.id);
                    final isSelected = realIndex == currentIndex;
                    
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: isSelected ? Colors.blueAccent.withAlpha(20) : Colors.transparent,
                      ),
                      child: ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        leading: Icon(
                          isSelected ? Icons.dashboard_rounded : Icons.dashboard_outlined, 
                          size: 18,
                          color: isSelected ? Colors.blueAccent : Colors.grey[600]
                        ),
                        title: Text(
                          page.name.toUpperCase(), 
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                            fontSize: 12,
                            letterSpacing: 0.5,
                            color: isSelected ? Colors.blueAccent : null
                          )
                        ),
                        trailing: isSelected ? Container(
                          width: 4,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.blueAccent,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(color: Colors.blueAccent.withAlpha(150), blurRadius: 4)
                            ]
                          ),
                        ) : null,
                        onTap: () {
                          ref.read(currentPageIndexProvider.notifier).value = realIndex;
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.greenAccent, width: 1.5),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.add_box_rounded, color: Colors.greenAccent, size: 28),
              title: const Text(
                'NEW DASHBOARD', 
                style: TextStyle(
                  fontWeight: FontWeight.w900, 
                  fontSize: 13, 
                  letterSpacing: 1.5, 
                  color: Colors.greenAccent
                )
              ),
              onTap: () => _showAddPageDialog(context, ref),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showAddPageDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('CREATE DASHBOARD', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: 'DISPLAY NAME (e.g. POWER-SUB)',
            hintStyle: TextStyle(fontSize: 10, color: Colors.grey.withAlpha(150), fontWeight: FontWeight.w800, letterSpacing: 1),
            filled: true,
            fillColor: Theme.of(context).scaffoldBackgroundColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text('CANCEL', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w900, fontSize: 12))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref.read(pagesProvider.notifier).addPage(controller.text);
                Navigator.pop(context);
              }
            }, 
            child: const Text('CREATE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12))
          ),
        ],
      ),
    );
  }
}

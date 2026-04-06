import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/layout_state.dart';
import '../providers/tm_state.dart';
import '../widgets/tm_cell.dart';
import '../widgets/sidebar.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPage = ref.watch(currentPageProvider);
    final isEditMode = ref.watch(editModeProvider);
    final status = ref.watch(systemStatusProvider);

    return Scaffold(
      drawer: const Sidebar(),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor.withAlpha(240),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor.withAlpha(50),
                width: 1,
              ),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (currentPage != null)
              Text(
                currentPage.name.toUpperCase(),
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.w900, 
                  letterSpacing: 1.2,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
            Row(
              children: [
                Icon(
                  Icons.satellite_alt_rounded, 
                  size: 12, 
                  color: Theme.of(context).primaryColor.withAlpha(200)
                ),
                const SizedBox(width: 4),
                Text(
                  '${status.satellite} GROUND STATION CONTROL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).primaryColor.withAlpha(180),
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // CONNECTION STATUS INDICATOR
          _ConnectionIndicator(status: status),
          const SizedBox(width: 12),

          if (isEditMode) ...[
            _AppBarActionButton(
              icon: Icons.add_box_outlined,
              tooltip: 'Add Row',
              onPressed: () {
                if (currentPage != null) {
                  final updatedPage = currentPage.addRow();
                  ref.read(pagesProvider.notifier).updatePage(updatedPage);
                }
              },
            ),
            _AppBarActionButton(
              icon: Icons.view_column_outlined,
              tooltip: 'Add Column',
              onPressed: () {
                if (currentPage != null) {
                  final updatedPage = currentPage.addColumn();
                  ref.read(pagesProvider.notifier).updatePage(updatedPage);
                }
              },
            ),
            Container(
              height: 24,
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: Theme.of(context).dividerColor.withAlpha(50),
            ),
          ],
          
          _AppBarActionButton(
            icon: ref.watch(themeProvider) == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            onPressed: () => ref.read(themeProvider.notifier).toggle(),
            tooltip: 'Toggle Theme',
          ),
          
          _AppBarActionButton(
            icon: isEditMode ? Icons.check_circle_rounded : Icons.edit_note_rounded,
            iconColor: isEditMode ? Colors.greenAccent : null,
            onPressed: () => ref.read(editModeProvider.notifier).toggle(),
            tooltip: isEditMode ? 'Save Layout' : 'Edit Layout',
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: currentPage == null
          ? const Center(child: CircularProgressIndicator())
          : _buildGrid(context, ref, currentPage, isEditMode),
    );
  }

  Widget _buildGrid(
    BuildContext context,
    WidgetRef ref,
    dynamic page,
    bool isEditMode,
  ) {
    final scrollControllerH = ScrollController();
    final scrollControllerV = ScrollController();

    return Scrollbar(
      controller: scrollControllerH,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: scrollControllerH,
        scrollDirection: Axis.horizontal,
        child: Scrollbar(
          controller: scrollControllerV,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: scrollControllerV,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int r = 0; r < page.grid.length; r++)
                    Row(
                      children: [
                        for (int c = 0; c < page.grid[r].length; c++)
                          Stack(
                            children: [
                              SizedBox(
                                width: 220, // Increased for better readability
                                height: 100, // Balanced for 2-value display
                                child: TMCell(
                                  row: r,
                                  col: c,
                                  cell: page.grid[r][c],
                                ),
                              ),
                              if (isEditMode) ...[
                                // Delete Column Button (only on first row)
                                if (r == 0 && page.grid[r].length > 1)
                                  Positioned(
                                    right: 4,
                                    top: 4,
                                    child: _DeleteBtn(
                                      icon: Icons.close,
                                      onTap: () {
                                        final updated = page.deleteColumn(c);
                                        ref
                                            .read(pagesProvider.notifier)
                                            .updatePage(updated);
                                      },
                                    ),
                                  ),
                                // Delete Row Button (only on last column)
                                if (c == page.grid[r].length - 1 &&
                                    page.grid.length > 1)
                                  Positioned(
                                    right: 4,
                                    bottom: 4,
                                    child: _DeleteBtn(
                                      icon: Icons.horizontal_rule,
                                      onTap: () {
                                        final updated = page.deleteRow(r);
                                        ref
                                            .read(pagesProvider.notifier)
                                            .updatePage(updated);
                                      },
                                    ),
                                  ),
                              ],
                            ],
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionIndicator extends StatelessWidget {
  final SystemStatus status;
  const _ConnectionIndicator({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status.connected ? Colors.greenAccent : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusDot(color: color),
          const SizedBox(width: 10),
          Text(
            status.connected ? 'SYSTEM LIVE' : 'DISCONNECTED',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final Color color;
  const _StatusDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(150),
            blurRadius: 6,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

class _AppBarActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final Color? iconColor;

  const _AppBarActionButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: IconButton(
        icon: Icon(icon, size: 20, color: iconColor),
        onPressed: onPressed,
        tooltip: tooltip,
        splashRadius: 24,
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _DeleteBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _DeleteBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.red.withAlpha(200),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 2, offset: const Offset(0, 1))
          ]
        ),
        child: Icon(icon, size: 10, color: Colors.white),
      ),
    );
  }
}

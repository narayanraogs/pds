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
    final isEditMode = ref.watch(editModeProvider);
    final status = ref.watch(systemStatusProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Row(
        children: [
          // ── PERMANENT NAVIGATION RAIL ────────────────────────────────────────
          const Sidebar(),

          // ── MAIN CONTENT ─────────────────────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                _TopBar(status: status, isEditMode: isEditMode, ref: ref, isDark: isDark),
                Expanded(child: _GridArea(isEditMode: isEditMode)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP BAR
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final SystemStatus status;
  final bool isEditMode;
  final WidgetRef ref;
  final bool isDark;

  const _TopBar({
    required this.status,
    required this.isEditMode,
    required this.ref,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final currentPage = ref.watch(currentPageProvider);
    final primary = Theme.of(context).primaryColor;
    final bg = isDark ? const Color(0xFF0D1321) : Colors.white;
    final border = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: border, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // PAGE TITLE
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (currentPage != null)
                  Text(
                    currentPage.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                Row(
                  children: [
                    Icon(Icons.satellite_alt_rounded, size: 10, color: primary),
                    const SizedBox(width: 4),
                    Text(
                      '${status.satellite} · GROUND CONTROL',
                      style: TextStyle(
                        fontSize: 9.5,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                        color: primary.withAlpha(190),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // EDIT MODE CONTROLS
          if (isEditMode) ...[
            _TopBarBtn(
              icon: Icons.add_box_outlined,
              label: 'ADD ROW',
              onPressed: () {
                if (currentPage != null) {
                  ref.read(pagesProvider.notifier).updatePage(currentPage.addRow());
                }
              },
            ),
            const SizedBox(width: 8),
            _TopBarBtn(
              icon: Icons.view_column_outlined,
              label: 'ADD COL',
              onPressed: () {
                if (currentPage != null) {
                  ref.read(pagesProvider.notifier).updatePage(currentPage.addColumn());
                }
              },
            ),
            const SizedBox(width: 16),
            _Divider(isDark: isDark),
            const SizedBox(width: 16),
          ],

          // CONNECTION STATUS
          _ConnectionPill(status: status),
          const SizedBox(width: 12),

          // THEME TOGGLE
          _IconBtn(
            icon: ref.watch(themeProvider) == ThemeMode.dark
                ? Icons.wb_sunny_rounded
                : Icons.dark_mode_rounded,
            tooltip: 'Toggle Theme',
            isDark: isDark,
            onPressed: () => ref.read(themeProvider.notifier).toggle(),
          ),
          const SizedBox(width: 4),

          // EDIT TOGGLE
          _EditToggleBtn(isEditMode: isEditMode, isDark: isDark, ref: ref),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: isDark ? Colors.white12 : Colors.black12,
    );
  }
}

class _TopBarBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _TopBarBtn({required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black12,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 14, color: isDark ? Colors.white70 : Colors.black54),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isDark;
  final VoidCallback onPressed;

  const _IconBtn({required this.icon, required this.tooltip, required this.isDark, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
          ),
          child: Icon(icon, size: 16, color: isDark ? Colors.white60 : Colors.black45),
        ),
      ),
    );
  }
}

class _EditToggleBtn extends StatelessWidget {
  final bool isEditMode;
  final bool isDark;
  final WidgetRef ref;

  const _EditToggleBtn({required this.isEditMode, required this.isDark, required this.ref});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return Tooltip(
      message: isEditMode ? 'Lock Layout' : 'Edit Layout',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => ref.read(editModeProvider.notifier).toggle(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isEditMode ? primary.withAlpha(30) : Colors.transparent,
            border: Border.all(
              color: isEditMode ? primary.withAlpha(180) : (isDark ? Colors.white12 : Colors.black12),
            ),
          ),
          child: Icon(
            isEditMode ? Icons.lock_open_rounded : Icons.edit_rounded,
            size: 16,
            color: isEditMode ? primary : (isDark ? Colors.white60 : Colors.black45),
          ),
        ),
      ),
    );
  }
}

class _ConnectionPill extends StatelessWidget {
  final SystemStatus status;
  const _ConnectionPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final isConnected = status.connected;
    final color = isConnected ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    final label = isConnected ? 'LIVE' : 'OFFLINE';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(80), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulsingDot(color: color, isAnimating: isConnected),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  final bool isAnimating;

  const _PulsingDot({required this.color, required this.isAnimating});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isAnimating) {
      return Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      );
    }
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: _animation.value),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: _animation.value * 0.7),
              blurRadius: 6,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GRID AREA
// ─────────────────────────────────────────────────────────────────────────────

class _GridArea extends ConsumerWidget {
  final bool isEditMode;
  const _GridArea({required this.isEditMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPage = ref.watch(currentPageProvider);

    if (currentPage == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.satellite_alt_rounded, size: 40, color: Colors.white12),
            const SizedBox(height: 12),
            Text(
              'SELECT A DISPLAY',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 2,
                color: Colors.white38,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    final scrollH = ScrollController();
    final scrollV = ScrollController();

    return Scrollbar(
      controller: scrollH,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: scrollH,
        scrollDirection: Axis.horizontal,
        child: Scrollbar(
          controller: scrollV,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: scrollV,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int r = 0; r < currentPage.grid.length; r++)
                    Row(
                      children: [
                        for (int c = 0; c < currentPage.grid[r].length; c++)
                          Stack(
                            children: [
                              SizedBox(
                                width: 228,
                                height: 104,
                                child: TMCell(
                                  row: r,
                                  col: c,
                                  cell: currentPage.grid[r][c],
                                ),
                              ),
                              if (isEditMode) ...[
                                if (r == 0 && currentPage.grid[r].length > 1)
                                  Positioned(
                                    right: 6,
                                    top: 6,
                                    child: _DeleteBtn(
                                      icon: Icons.close_rounded,
                                      onTap: () {
                                        ref.read(pagesProvider.notifier).updatePage(
                                              currentPage.deleteColumn(c));
                                      },
                                    ),
                                  ),
                                if (c == currentPage.grid[r].length - 1 &&
                                    currentPage.grid.length > 1)
                                  Positioned(
                                    right: 6,
                                    bottom: 6,
                                    child: _DeleteBtn(
                                      icon: Icons.remove_rounded,
                                      onTap: () {
                                        ref.read(pagesProvider.notifier).updatePage(
                                              currentPage.deleteRow(r));
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

class _DeleteBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _DeleteBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEF4444).withAlpha(100),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(icon, size: 12, color: Colors.white),
      ),
    );
  }
}

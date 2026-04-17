import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/layout_state.dart';
import '../providers/tm_state.dart';
import '../widgets/tm_cell.dart';
import '../widgets/sidebar.dart';
import '../models/page_layout.dart';
import '../widgets/derived_param_panel.dart';


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
                _RibbonArea(isDark: isDark),
                Expanded(child: _MainContentArea(isEditMode: isEditMode)),
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
              icon: Icons.view_column_outlined,
              label: 'NEW COLUMN',
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

          // DERIVED PARAMS TOGGLE
          _IconBtn(
            icon: Icons.functions_rounded,
            tooltip: 'Derived Parameters',
            isDark: isDark,
            onPressed: () => showDerivedParamPanel(context, ref),
          ),
          const SizedBox(width: 4),

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
    Color color;
    String label;
    bool animate;

    switch (status.state) {
      case TMConnectionState.live:
        color = const Color(0xFF22C55E);
        label = 'LIVE';
        animate = true;
      case TMConnectionState.connected:
        color = const Color(0xFFF59E0B);
        label = 'SC OFF';
        animate = false;
      case TMConnectionState.disconnected:
        color = const Color(0xFFEF4444);
        label = 'OFFLINE';
        animate = false;
    }

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
          _PulsingDot(color: color, isAnimating: animate),
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
// STATS RIBBON (Always Visible)
// ─────────────────────────────────────────────────────────────────────────────

class _RibbonArea extends ConsumerWidget {
  final bool isDark;
  const _RibbonArea({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(systemStatusProvider);
    final bg = isDark ? const Color(0xFF0D1321) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return Container(
      height: 44,
      width: double.infinity,
      decoration: BoxDecoration(
        color: bg.withAlpha(200), // Slight transparency
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            for (final m in status.ribbon)
              _RibbonItem(mnemonic: m, isDark: isDark),
          ],
        ),
      ),
    );
  }
}

class _RibbonItem extends ConsumerWidget {
  final String mnemonic;
  final bool isDark;
  const _RibbonItem({required this.mnemonic, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final param = ref.watch(parameterProvider(mnemonic));
    final primary = Theme.of(context).primaryColor;

    return Container(
      margin: const EdgeInsets.only(right: 32),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: primary.withAlpha(100),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mnemonic.replaceAll('_', ' '),
                style: TextStyle(
                  fontSize: 7.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: isDark ? Colors.white30 : Colors.black38,
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  _ValueStream(label: 'T1', value: param?.tm1Value ?? '---', isDark: isDark, primary: primary),
                  const SizedBox(width: 10),
                  _ValueStream(label: 'T2', value: param?.tm2Value ?? '---', isDark: isDark, primary: primary),
                  const SizedBox(width: 4),
                  if (param?.units.isNotEmpty ?? false)
                    Text(
                      param!.units,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                        color: primary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ValueStream extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final Color primary;

  const _ValueStream({required this.label, required this.value, required this.isDark, required this.primary});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 7,
            fontWeight: FontWeight.w900,
            color: primary.withAlpha(120),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONTENT AREA SWITCHER
// ─────────────────────────────────────────────────────────────────────────────

class _MainContentArea extends ConsumerWidget {
  final bool isEditMode;
  const _MainContentArea({required this.isEditMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _GridArea(isEditMode: isEditMode);
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
            const Icon(Icons.satellite_alt_rounded, size: 40, color: Colors.white12),
            const SizedBox(height: 12),
            const Text(
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
              padding: const EdgeInsets.all(24.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int c = 0; c < currentPage.columns.length; c++) ...[
                    Column(
                      children: [
                        if (isEditMode)
                          _InsertBtn(
                            isVertical: false,
                            onTap: () {
                              ref.read(pagesProvider.notifier).updatePage(
                                    currentPage.addCell(c, rowIndex: 0),
                                  );
                            },
                            onAccept: (data) {
                              ref.read(pagesProvider.notifier).updatePage(
                                    currentPage.moveCell(data.col, data.row, c, 0),
                                  );
                            },
                          ),
                        for (int r = 0; r < currentPage.columns[c].length; r++) ...[
                          _CellWrapper(
                            r: r,
                            c: c,
                            currentPage: currentPage,
                            isEditMode: isEditMode,
                            ref: ref,
                          ),
                          if (isEditMode)
                            _InsertBtn(
                              isVertical: false,
                              onTap: () {
                                ref.read(pagesProvider.notifier).updatePage(
                                      currentPage.addCell(c, rowIndex: r + 1),
                                    );
                              },
                              onAccept: (data) {
                                ref.read(pagesProvider.notifier).updatePage(
                                      currentPage.moveCell(data.col, data.row, c, r + 1),
                                    );
                              },
                            ),
                        ],
                      ],
                    ),
                    if (isEditMode)
                      _InsertBtn(
                        isVertical: true,
                        onTap: () {
                          ref.read(pagesProvider.notifier).updatePage(
                                currentPage.addColumn(index: c + 1),
                              );
                        },
                        onAccept: (data) {
                          ref.read(pagesProvider.notifier).updatePage(
                                currentPage.moveCellToNewColumn(data.col, data.row, c + 1),
                              );
                        },
                      ),
                  ],
                  if (currentPage.columns.isEmpty && isEditMode)
                    _TopBarBtn(
                      icon: Icons.add_rounded,
                      label: 'CREATE FIRST COLUMN',
                      onPressed: () {
                        ref.read(pagesProvider.notifier).updatePage(currentPage.addColumn());
                      },
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

class CellDragData {
  final int col;
  final int row;
  CellDragData({required this.col, required this.row});
}

class _CellWrapper extends StatelessWidget {
  final int r;
  final int c;
  final PageLayout currentPage;
  final bool isEditMode;
  final WidgetRef ref;

  const _CellWrapper({
    required this.r,
    required this.c,
    required this.currentPage,
    required this.isEditMode,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    Widget cellWidget = SizedBox(
      width: 228,
      height: 104,
      child: TMCell(
        row: r,
        col: c,
        cell: currentPage.columns[c][r],
      ),
    );

    if (isEditMode) {
      cellWidget = LongPressDraggable<CellDragData>(
        delay: const Duration(milliseconds: 150),
        data: CellDragData(col: c, row: r),
        feedback: Material(
          color: Colors.transparent,
          child: Opacity(
            opacity: 0.8,
            child: cellWidget,
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.3,
          child: cellWidget,
        ),
        child: cellWidget,
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        cellWidget,
        if (isEditMode) ...[
          // Cell Delete (always visible)
          Positioned(
            right: -8,
            top: -8,
            child: _DeleteBtn(
              icon: Icons.remove_rounded,
              tooltip: 'Delete Cell',
              onTap: () {
                ref.read(pagesProvider.notifier).updatePage(
                      currentPage.deleteCell(c, r),
                    );
              },
            ),
          ),
          // Column Delete (at top cell only)
          if (r == 0 && currentPage.columns.length > 1)
            Positioned(
              left: -8,
              top: -8,
              child: _DeleteBtn(
                icon: Icons.close_rounded,
                tooltip: 'Delete Entire Column',
                onTap: () {
                  ref.read(pagesProvider.notifier).updatePage(
                        currentPage.deleteColumn(c),
                      );
                },
              ),
            ),
        ],
      ],
    );
  }
}

class _InsertBtn extends StatelessWidget {
  final bool isVertical;
  final VoidCallback onTap;
  final void Function(CellDragData)? onAccept;

  const _InsertBtn({
    required this.isVertical,
    required this.onTap,
    this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return DragTarget<CellDragData>(
      onAcceptWithDetails: (details) {
        if (onAccept != null) onAccept!(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return InkWell(
          onTap: onTap,
          hoverColor: Colors.transparent,
          child: Container(
            width: isVertical ? 24 : 228,
            height: isVertical ? 104 : 24,
            alignment: Alignment.center,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // The thin/thick line
                Container(
                  width: isVertical ? (isHovered ? 4 : 1) : (isHovered ? 120 : 40),
                  height: isVertical ? (isHovered ? 60 : 40) : (isHovered ? 4 : 1),
                  decoration: BoxDecoration(
                    color: isHovered ? primary.withAlpha(200) : primary.withAlpha(40),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // The plus button
                Container(
                  width: isHovered ? 24 : 18,
                  height: isHovered ? 24 : 18,
                  decoration: BoxDecoration(
                    color: isHovered ? primary.withAlpha(200) : primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primary.withAlpha(isHovered ? 150 : 80),
                        blurRadius: isHovered ? 8 : 4,
                        spreadRadius: isHovered ? 2 : 1,
                      ),
                    ],
                  ),
                  child: Icon(Icons.add, size: isHovered ? 16 : 12, color: Colors.white),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DeleteBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _DeleteBtn({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white24, width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEF4444).withAlpha(120),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(icon, size: 12, color: Colors.white),
        ),
      ),
    );
  }
}

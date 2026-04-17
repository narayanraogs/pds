import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/page_layout.dart';
import '../models/tm_parameter.dart';
import '../providers/tm_state.dart';
import '../providers/layout_state.dart';
import '../providers/derived_state.dart';
import 'sparkline.dart';
import 'parameter_picker.dart';

class TMCell extends ConsumerWidget {
  final int row;
  final int col;
  final CellData cell;

  const TMCell({
    super.key,
    required this.row,
    required this.col,
    required this.cell,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditMode = ref.watch(editModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF0D1321) : Colors.white;
    final borderColor = isEditMode
        ? Theme.of(context).primaryColor.withAlpha(180)
        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      margin: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: isEditMode ? 1.5 : 1),
        boxShadow: [
          if (!isEditMode)
            BoxShadow(
              color: isDark ? Colors.black.withAlpha(120) : Colors.black.withAlpha(14),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          if (isEditMode)
            BoxShadow(
              color: Theme.of(context).primaryColor.withAlpha(35),
              blurRadius: 12,
              spreadRadius: 1,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: _buildContent(context, ref, isEditMode, isDark),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, bool isEditMode, bool isDark) {
    switch (cell.type) {
      case CellType.empty:
        return isEditMode
            ? _EmptyAddCell(onTap: () => _showConfigDialog(context, ref), isDark: isDark)
            : const SizedBox.shrink();

      case CellType.header:
        return _HeaderCell(
          content: cell.content,
          isDark: isDark,
          isEditMode: isEditMode,
          onTap: () => _showConfigDialog(context, ref),
          primary: Theme.of(context).primaryColor,
        );

      case CellType.parameter:
        final param = ref.watch(parameterProvider(cell.content));
        if (param == null) {
          return Center(
            child: Text(
              'ERR: ${cell.content}',
              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.w700),
            ),
          );
        }
        
        final derivedList = ref.watch(derivedParamProvider).value ?? [];
        final isDerived = derivedList.any((d) => d.mnemonic == param.mnemonic);

        return _ParameterCell(
          param: param,
          isDerived: isDerived,
          isDark: isDark,
          isEditMode: isEditMode,
          onTap: () => _showConfigDialog(context, ref),
          primary: Theme.of(context).primaryColor,
        );
    }
  }

  void _showConfigDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => ParameterPicker(
        onSelect: (type, content) {
          final currentPage = ref.read(currentPageProvider);
          if (currentPage != null) {
            ref.read(pagesProvider.notifier).updatePage(
                  currentPage.updateCell(col, row, cell.copyWith(type: type, content: content)));
          }
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY CELL — Edit Mode Placeholder
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyAddCell extends StatefulWidget {
  final VoidCallback onTap;
  final bool isDark;
  const _EmptyAddCell({required this.onTap, required this.isDark});

  @override
  State<_EmptyAddCell> createState() => _EmptyAddCellState();
}

class _EmptyAddCellState extends State<_EmptyAddCell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          color: _hovered
              ? primary.withAlpha(widget.isDark ? 20 : 12)
              : Colors.transparent,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_rounded,
                  size: 22,
                  color: primary.withAlpha(_hovered ? 200 : 100),
                ),
                const SizedBox(height: 2),
                Text(
                  'ADD',
                  style: TextStyle(
                    fontSize: 8,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                    color: primary.withAlpha(_hovered ? 200 : 100),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER CELL
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderCell extends StatelessWidget {
  final String content;
  final bool isDark;
  final bool isEditMode;
  final VoidCallback onTap;
  final Color primary;

  const _HeaderCell({
    required this.content,
    required this.isDark,
    required this.isEditMode,
    required this.onTap,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isEditMode ? onTap : null,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [primary.withAlpha(25), primary.withAlpha(10)]
                : [primary.withAlpha(18), primary.withAlpha(8)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.view_module_rounded, size: 16, color: primary.withAlpha(120)),
              const SizedBox(height: 6),
              Text(
                content.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 2,
                  color: primary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PARAMETER CELL
// ─────────────────────────────────────────────────────────────────────────────

class _ParameterCell extends StatelessWidget {
  final TMParameter param;
  final bool isDark;
  final bool isEditMode;
  final bool isDerived;
  final VoidCallback onTap;
  final Color primary;

  const _ParameterCell({
    required this.param,
    required this.isDark,
    required this.isEditMode,
    required this.isDerived,
    required this.onTap,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final headerBg = isDark ? Colors.white.withAlpha(6) : const Color(0xFFF8FAFC);
    final headerBorder = isDark ? Colors.white.withAlpha(12) : const Color(0xFFE2E8F0);

    return InkWell(
      onTap: isEditMode ? onTap : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── MNEMONIC HEADER ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: headerBg,
              border: Border(bottom: BorderSide(color: headerBorder, width: 1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        param.mnemonic,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                          color: primary,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (param.units.isNotEmpty) ...[
                        const SizedBox(width: 5),
                        Text(
                          param.units,
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            color: primary.withAlpha(120),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Tooltip(
                  message: isDerived ? 'Computed Parameters' : 'Native Satellite Telemetry',
                  child: Icon(
                    isDerived ? Icons.functions_rounded : Icons.satellite_alt_rounded,
                    size: 13,
                    color: isDark ? Colors.white24 : Colors.black.withAlpha(51),
                  ),
                ),
              ],
            ),
          ),

          // ── VALUE BOXES ─────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  _ValueBox(
                    label: 'TM1',
                    value: param.tm1Value,
                    status: param.status1,
                    isDark: isDark,
                    history: param.tm1History,
                    min: param.lowerLimit != 0 ? param.lowerLimit : null,
                    max: param.upperLimit != 0 ? param.upperLimit : null,
                  ),
                  const SizedBox(width: 6),
                  _ValueBox(
                    label: 'TM2',
                    value: param.tm2Value,
                    status: param.status2,
                    isDark: isDark,
                    history: param.tm2History,
                    min: param.lowerLimit != 0 ? param.lowerLimit : null,
                    max: param.upperLimit != 0 ? param.upperLimit : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VALUE BOX
// ─────────────────────────────────────────────────────────────────────────────


class _ValueBox extends StatelessWidget {
  final String label;
  final String value;
  final TMStatus status;
  final bool isDark;
  final List<double> history;
  final double? min;
  final double? max;

  const _ValueBox({
    required this.label,
    required this.value,
    required this.status,
    required this.isDark,
    required this.history,
    this.min,
    this.max,
  });

  static const _statusColors = {
    TMStatus.normal:       Color(0xFF22C55E),
    TMStatus.nearUpper:    Color(0xFFF59E0B),
    TMStatus.nearLower:    Color(0xFFF59E0B),
    TMStatus.crossedUpper: Color(0xFFEF4444),
    TMStatus.crossedLower: Color(0xFFEF4444),
  };

  @override
  Widget build(BuildContext context) {
    final color = _statusColors[status] ?? const Color(0xFF22C55E);
    final displayVal = value.isEmpty ? '---' : value;

    return Expanded(
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isDark
              ? color.withAlpha(18)
              : color.withAlpha(14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? color.withAlpha(80) : color.withAlpha(60),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            // TREND LINE (Background)
            Positioned(
              left: 0, right: 0, bottom: 0, top: 32,
              child: Opacity(
                opacity: 0.6,
                child: Sparkline(
                  data: history,
                  color: color,
                  min: min,
                  max: max,
                ),
              ),
            ),
            
            // CONTENT
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // STATUS DOT + LABEL
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          boxShadow: status != TMStatus.normal
                              ? [BoxShadow(color: color.withAlpha(140), blurRadius: 5, spreadRadius: 1)]
                              : null,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // VALUE
                  Text(
                    displayVal,
                    style: TextStyle(
                      fontSize: 17,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w900,
                      color: displayVal == '---'
                          ? (isDark ? Colors.white24 : Colors.black26)
                          : (isDark ? Colors.white : const Color(0xFF0F172A)),
                      letterSpacing: -0.5,
                      shadows: [
                         if (isDark)
                           Shadow(color: Colors.black.withAlpha(150), blurRadius: 8),
                      ]
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

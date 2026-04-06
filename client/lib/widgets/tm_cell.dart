import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/page_layout.dart';
import '../models/tm_parameter.dart';
import '../providers/tm_state.dart';
import '../providers/layout_state.dart';
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2128) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEditMode
              ? Theme.of(context).primaryColor.withAlpha(220)
              : (isDark
                    ? Colors.white.withAlpha(100)  // HEAVILY INCREASED CONTRAST
                    : Colors.black.withAlpha(60)), // HEAVILY INCREASED CONTRAST
          width: isEditMode ? 2 : 1.5,
        ),
        boxShadow: [
          if (!isEditMode) ...[
            // LAYERED SHADOW FOR DEPTH
            BoxShadow(
              color: isDark
                  ? Colors.black.withAlpha(180)
                  : Colors.black.withAlpha(20),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
            if (!isDark)
              BoxShadow(
                color: Colors.blueAccent.withAlpha(5),
                blurRadius: 20,
                spreadRadius: 2,
              ),
          ],
          if (isEditMode)
            BoxShadow(
              color: Theme.of(context).primaryColor.withAlpha(40),
              blurRadius: 15,
              spreadRadius: 2,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? null
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white,
                      const Color(0xFFF9FAFB).withAlpha(200),
                    ],
                  ),
          ),
          child: _buildContent(context, ref, isEditMode),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, bool isEditMode) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (cell.type) {
      case CellType.empty:
        return isEditMode
            ? Center(
                child: IconButton(
                  icon: Icon(
                    Icons.add_circle_rounded,
                    size: 32,
                    color: Theme.of(context).primaryColor.withAlpha(150),
                  ),
                  onPressed: () => _showConfigDialog(context, ref),
                ),
              )
            : const SizedBox.shrink();

      case CellType.header:
        return InkWell(
          onTap: isEditMode ? () => _showConfigDialog(context, ref) : null,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).primaryColor.withAlpha(isDark ? 30 : 15),
                  Theme.of(context).primaryColor.withAlpha(isDark ? 10 : 5),
                ],
              ),
            ),
            child: Center(
              child: Text(
                cell.content.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).primaryColor,
                  fontSize: 12,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );

      case CellType.parameter:
        final param = ref.watch(parameterProvider(cell.content));
        if (param == null)
          return const Center(
            child: Text('ERR', style: TextStyle(color: Colors.red)),
          );

        return InkWell(
          onTap: isEditMode ? () => _showConfigDialog(context, ref) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // MNEMONIC HEADER (PREMIUM STYLE)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withAlpha(5)
                      : const Color(0xFFF3F4F6),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? Colors.white.withAlpha(10)
                          : Colors.black.withAlpha(5),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        param.mnemonic,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          color: Theme.of(context).primaryColor,
                          letterSpacing: 0.8,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.monitor_heart_rounded,
                      size: 12,
                      color: Theme.of(context).primaryColor.withAlpha(180),
                    ),
                  ],
                ),
              ),

              // VALUES AREA
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Row(
                    children: [
                      _ValueBox(
                        label: 'TM1',
                        value: param.tm1Value,
                        units: param.units,
                        status: param.status1,
                      ),
                      const SizedBox(width: 10),
                      _ValueBox(
                        label: 'TM2',
                        value: param.tm2Value,
                        units: param.units,
                        status: param.status2,
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

  void _showConfigDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => ParameterPicker(
        onSelect: (type, content) {
          final currentPage = ref.read(currentPageProvider);
          if (currentPage != null) {
            final updatedPage = currentPage.updateCell(
              row,
              col,
              cell.copyWith(type: type, content: content),
            );
            ref.read(pagesProvider.notifier).updatePage(updatedPage);
          }
        },
      ),
    );
  }
}

class _ValueBox extends StatelessWidget {
  final String label;
  final String value;
  final String units;
  final TMStatus status;

  const _ValueBox({
    required this.label,
    required this.value,
    required this.units,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = TMParameter.getStatusColor(status);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: statusColor.withAlpha(isDark ? 30 : 20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: statusColor.withAlpha(isDark ? 150 : 120),
            width: 1.5,
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: statusColor.withAlpha(10),
                blurRadius: 4,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 8,
                color: isDark ? Colors.white70 : Colors.black45,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value.isEmpty ? "---" : value,
                  style: TextStyle(
                    fontSize: 18,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                    letterSpacing: -1,
                  ),
                ),
                if (units.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(
                    units,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white54 : Colors.black38,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

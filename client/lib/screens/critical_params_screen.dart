import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/critical_parameter.dart';
import '../providers/critical_state.dart';
import '../providers/tm_state.dart';
import '../widgets/critical_chart_painter.dart';
import '../widgets/parameter_picker.dart';

final criticalFilterModeProvider = NotifierProvider<CriticalFilterNotifier, bool>(() {
  return CriticalFilterNotifier();
});

class CriticalFilterNotifier extends Notifier<bool> {
  @override
  bool build() => true; // Default: show active parameters only
  void toggle() => state = !state;
  set value(bool v) => state = v;
}

class CriticalParamsScreen extends ConsumerWidget {
  const CriticalParamsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final criticalsAsync = ref.watch(criticalParamsProvider);
    final showOnlyActive = ref.watch(criticalFilterModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;
    final bg = isDark ? const Color(0xFF090D16) : const Color(0xFFF1F5F9);

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // Header Bar
          _HeaderBar(isDark: isDark, primary: primary),

          // Content Area
          Expanded(
            child: criticalsAsync.when(
              data: (criticalList) {
                if (criticalList.isEmpty) {
                  return _EmptyCriticalState(isDark: isDark, primary: primary);
                }

                final displayList = showOnlyActive
                    ? criticalList.where((cp) => cp.isActive).toList()
                    : criticalList;

                if (displayList.isEmpty && showOnlyActive) {
                  return _NoActiveCriticalState(
                    isDark: isDark,
                    primary: primary,
                    totalCount: criticalList.length,
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 480,
                    mainAxisExtent: 320,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: displayList.length,
                  itemBuilder: (context, index) {
                    final cp = displayList[index];
                    return _CriticalCard(key: ValueKey(cp.id), cp: cp, isDark: isDark, primary: primary);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text(
                  'Error loading critical parameters: $err',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderBar extends ConsumerWidget {
  final bool isDark;
  final Color primary;

  const _HeaderBar({required this.isDark, required this.primary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final headerBg = isDark ? const Color(0xFF0D1321) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final criticals = ref.watch(criticalParamsProvider).value ?? [];
    final activeCount = criticals.where((c) => c.isActive).length;
    final showOnlyActive = ref.watch(criticalFilterModeProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: headerBg,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CRITICAL PARAMETERS MONITOR',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Active: $activeCount / ${criticals.length} Tiles Monitored',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ],
          ),
          const Spacer(),

          // Segmented Active / All Filter Toggle
          Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _FilterTabButton(
                  label: 'ACTIVE ($activeCount)',
                  isSelected: showOnlyActive,
                  primary: primary,
                  isDark: isDark,
                  onTap: () => ref.read(criticalFilterModeProvider.notifier).value = true,
                ),
                _FilterTabButton(
                  label: 'ALL (${criticals.length})',
                  isSelected: !showOnlyActive,
                  primary: primary,
                  isDark: isDark,
                  onTap: () => ref.read(criticalFilterModeProvider.notifier).value = false,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Manage Quick Tiles Button
          OutlinedButton.icon(
            onPressed: () => _showManageTilesDrawer(context, ref, criticals),
            icon: const Icon(Icons.tune_rounded, size: 16),
            label: const Text('Manage Quick Tiles'),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? Colors.white : Colors.black87,
              side: BorderSide(color: borderColor),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(width: 12),

          // Add Critical Parameter Button
          ElevatedButton.icon(
            onPressed: () => _showAddParameterModal(context, ref),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Parameter'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 2,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddParameterModal(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => ParameterPicker(
        allowHeader: false,
        onSelect: (type, mnemonic) {
          if (mnemonic.isEmpty) return;
          Future.microtask(() {
            if (!context.mounted) return;
            final tmMap = ref.read(tmRegistryProvider);
            final fetchedParam = tmMap[mnemonic];

            double defaultLower = fetchedParam?.lowerLimit ?? 0.0;
            double defaultUpper = fetchedParam?.upperLimit ?? 100.0;

            _showLimitEditModal(
              context: context,
              ref: ref,
              cp: CriticalParameter(
                id: const Uuid().v4(),
                mnemonic: mnemonic,
                lowerLimit: defaultLower,
                upperLimit: defaultUpper,
                maxChangeThreshold: 0.0,
                isActive: true,
              ),
              isNew: true,
            );
          });
        },
      ),
    );
  }
}

class _FilterTabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color primary;
  final bool isDark;
  final VoidCallback onTap;

  const _FilterTabButton({
    required this.label,
    required this.isSelected,
    required this.primary,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primary.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            color: isSelected ? primary : (isDark ? Colors.white60 : Colors.black54),
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _EmptyCriticalState extends ConsumerWidget {
  final bool isDark;
  final Color primary;

  const _EmptyCriticalState({required this.isDark, required this.primary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.show_chart_rounded, size: 64, color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 16),
          Text(
            'No Critical Parameters Configured',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add satellite parameters to monitor real-time value curves with upper and lower thresholds.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : Colors.black45,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (dialogContext) => ParameterPicker(
                  allowHeader: false,
                  onSelect: (type, mnemonic) {
                    if (mnemonic.isEmpty) return;
                    Future.microtask(() {
                      if (!context.mounted) return;
                      final tmMap = ref.read(tmRegistryProvider);
                      final fetchedParam = tmMap[mnemonic];

                      double defaultLower = fetchedParam?.lowerLimit ?? 0.0;
                      double defaultUpper = fetchedParam?.upperLimit ?? 100.0;

                      _showLimitEditModal(
                        context: context,
                        ref: ref,
                        cp: CriticalParameter(
                          id: const Uuid().v4(),
                          mnemonic: mnemonic,
                          lowerLimit: defaultLower,
                          upperLimit: defaultUpper,
                          maxChangeThreshold: 0.0,
                          isActive: true,
                        ),
                        isNew: true,
                      );
                    });
                  },
                ),
              );
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Critical Parameter'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoActiveCriticalState extends ConsumerWidget {
  final bool isDark;
  final Color primary;
  final int totalCount;

  const _NoActiveCriticalState({
    required this.isDark,
    required this.primary,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.visibility_off_rounded, size: 56, color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 16),
          Text(
            'All Configured Parameters are Deactivated ($totalCount Total)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Switch filter view to "ALL" or open "Manage Quick Tiles" to toggle parameters back on.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : Colors.black45,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => ref.read(criticalFilterModeProvider.notifier).value = false,
            icon: const Icon(Icons.view_module_rounded, size: 16),
            label: const Text('Show All Configured Tiles'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CriticalCard extends ConsumerStatefulWidget {
  final CriticalParameter cp;
  final bool isDark;
  final Color primary;

  const _CriticalCard({
    super.key,
    required this.cp,
    required this.isDark,
    required this.primary,
  });

  @override
  ConsumerState<_CriticalCard> createState() => _CriticalCardState();
}

class _CriticalCardState extends ConsumerState<_CriticalCard> {
  bool _isSpikeLatched = false;
  double _latchedSpikeDelta = 0.0;
  double? _lastVal1;
  double? _lastVal2;

  void _checkRateOfChangeSpike(double? val1, double? val2) {
    if (!widget.cp.isActive || widget.cp.maxChangeThreshold <= 0.0) return;

    if (val1 != null && _lastVal1 != null) {
      final delta1 = (val1 - _lastVal1!).abs();
      if (delta1 > widget.cp.maxChangeThreshold) {
        _isSpikeLatched = true;
        _latchedSpikeDelta = max(_latchedSpikeDelta, delta1);
      }
    }
    if (val1 != null) _lastVal1 = val1;

    if (val2 != null && _lastVal2 != null) {
      final delta2 = (val2 - _lastVal2!).abs();
      if (delta2 > widget.cp.maxChangeThreshold) {
        _isSpikeLatched = true;
        _latchedSpikeDelta = max(_latchedSpikeDelta, delta2);
      }
    }
    if (val2 != null) _lastVal2 = val2;
  }

  @override
  Widget build(BuildContext context) {
    final cp = widget.cp;
    final isDark = widget.isDark;
    final primary = widget.primary;

    final param = ref.watch(parameterProvider(cp.mnemonic));
    final tm1History = param?.tm1History ?? [];
    final tm2History = param?.tm2History ?? [];
    final tm1Str = param?.tm1Value ?? '';
    final tm2Str = param?.tm2Value ?? '';

    final val1 = double.tryParse(tm1Str);
    final val2 = double.tryParse(tm2Str);

    _checkRateOfChangeSpike(val1, val2);

    bool isViolated1 = false;
    bool isViolated2 = false;

    if (cp.isActive && val1 != null) {
      if ((cp.upperLimit != 0 && val1 > cp.upperLimit) || (cp.lowerLimit != 0 && val1 < cp.lowerLimit)) {
        isViolated1 = true;
      }
    }

    if (cp.isActive && val2 != null) {
      if ((cp.upperLimit != 0 && val2 > cp.upperLimit) || (cp.lowerLimit != 0 && val2 < cp.lowerLimit)) {
        isViolated2 = true;
      }
    }

    final isLimitViolated = cp.isActive && (isViolated1 || isViolated2);
    final isAnyAlarm = isLimitViolated || _isSpikeLatched;

    final cardBg = isDark ? const Color(0xFF0D1321) : Colors.white;

    final borderColor = isAnyAlarm
        ? const Color(0xFFEF4444)
        : (cp.isActive
            ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))
            : (isDark ? Colors.white10 : Colors.black12));

    return Opacity(
      opacity: cp.isActive ? 1.0 : 0.55,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: isAnyAlarm ? 2.5 : 1),
          boxShadow: [
            if (isAnyAlarm)
              BoxShadow(
                color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                blurRadius: 18,
                spreadRadius: 2,
              )
            else
              BoxShadow(
                color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isAnyAlarm
                    ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                    : (isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC)),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                border: Border(bottom: BorderSide(color: borderColor, width: 1)),
              ),
              child: Row(
                children: [
                  // Active Toggle Switch
                  Tooltip(
                    message: cp.isActive ? 'Deactivate Monitoring' : 'Activate Monitoring',
                    child: Transform.scale(
                      scale: 0.75,
                      child: Switch.adaptive(
                        value: cp.isActive,
                        activeTrackColor: const Color(0xFF10B981),
                        onChanged: (val) {
                          ref.read(criticalParamsProvider.notifier).saveCriticalParam(
                                cp.copyWith(isActive: val),
                              );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),

                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          cp.mnemonic,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                            color: isAnyAlarm ? const Color(0xFFEF4444) : (cp.isActive ? primary : Colors.grey),
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (param != null && param.units.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(${param.units})',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white38 : Colors.black45,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Sticky Alarm Badge & Clear Action
                  if (_isSpikeLatched) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'SPIKE |Δ|=${_latchedSpikeDelta.toStringAsFixed(1)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _isSpikeLatched = false;
                          _latchedSpikeDelta = 0.0;
                        });
                      },
                      icon: const Icon(Icons.notifications_off_rounded, size: 12, color: Colors.white),
                      label: const Text(
                        'CLEAR',
                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFB91C1C),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ] else if (isLimitViolated) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'ALARM',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],

                  if (!cp.isActive) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'OFF',
                        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],

                  IconButton(
                    icon: const Icon(Icons.tune_rounded, size: 15),
                    tooltip: 'Edit Limit Bounds',
                    onPressed: () => _showLimitEditModal(context: context, ref: ref, cp: cp, isNew: false),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Colors.redAccent),
                    tooltip: 'Remove Critical Parameter',
                    onPressed: () => ref.read(criticalParamsProvider.notifier).deleteCriticalParam(cp.id),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Real-Time Dual Metric Bar (TM1 & TM2)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                children: [
                  _TelemetryValueBox(
                    label: 'TM1',
                    value: tm1Str,
                    color: isViolated1 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 12),
                  _TelemetryValueBox(
                    label: 'TM2',
                    value: tm2Str,
                    color: isViolated2 ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
                    isDark: isDark,
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'LOWER: ${cp.lowerLimit.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                          color: Color(0xFFEF4444),
                        ),
                      ),
                      Text(
                        'UPPER: ${cp.upperLimit.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                          color: Color(0xFFEF4444),
                        ),
                      ),
                      if (cp.maxChangeThreshold > 0.0)
                        Text(
                          'MAX Δ: ${cp.maxChangeThreshold.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                            color: Colors.orangeAccent,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Real-Time Canvas Graph (Dual TM Curves)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: CustomPaint(
                  painter: CriticalChartPainter(
                    tm1History: tm1History,
                    tm2History: tm2History,
                    lowerLimit: cp.lowerLimit,
                    upperLimit: cp.upperLimit,
                    isDark: isDark,
                    isViolated1: isViolated1 || _isSpikeLatched,
                    isViolated2: isViolated2 || _isSpikeLatched,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TelemetryValueBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _TelemetryValueBox({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final displayVal = value.isEmpty ? '---' : value;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            displayVal,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              color: displayVal == '---'
                  ? (isDark ? Colors.white24 : Colors.black26)
                  : (isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }
}

void _showManageTilesDrawer(BuildContext context, WidgetRef ref, List<CriticalParameter> initialParams) {
  showDialog(
    context: context,
    builder: (context) => Consumer(
      builder: (context, ref, child) {
        final currentParams = ref.watch(criticalParamsProvider).value ?? initialParams;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bg = isDark ? const Color(0xFF0D1321) : Colors.white;
        final border = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

        return Dialog(
          backgroundColor: bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 540,
            height: 550,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.widgets_rounded, color: Colors.blueAccent, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Manage Quick-Settings Tiles',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Toggle monitoring switches to show or hide tiles on your active telemetry grid.',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: currentParams.isEmpty
                      ? const Center(child: Text('No parameters configured.'))
                      : ListView.separated(
                          itemCount: currentParams.length,
                          separatorBuilder: (_, _) => Divider(color: border, height: 1),
                          itemBuilder: (context, index) {
                            final cp = currentParams[index];
                            return SwitchListTile.adaptive(
                              title: Text(
                                cp.mnemonic,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: Text(
                                'Lower: ${cp.lowerLimit.toStringAsFixed(2)} | Upper: ${cp.upperLimit.toStringAsFixed(2)} | Max Δ: ${cp.maxChangeThreshold.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white38 : Colors.black45,
                                ),
                              ),
                              value: cp.isActive,
                              activeTrackColor: const Color(0xFF10B981),
                              onChanged: (val) {
                                ref.read(criticalParamsProvider.notifier).saveCriticalParam(
                                      cp.copyWith(isActive: val),
                                    );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

void _showLimitEditModal({
  required BuildContext context,
  required WidgetRef ref,
  required CriticalParameter cp,
  required bool isNew,
}) {
  final lowerController = TextEditingController(text: cp.lowerLimit.toString());
  final upperController = TextEditingController(text: cp.upperLimit.toString());
  final deltaController = TextEditingController(text: cp.maxChangeThreshold.toString());

  showDialog(
    context: context,
    builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0D1321) : Colors.white,
        title: Text(
          '${isNew ? "Configure" : "Edit"} Critical Limits: ${cp.mnemonic}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: lowerController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: const InputDecoration(
                labelText: 'Lower Limit Threshold',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: upperController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: const InputDecoration(
                labelText: 'Upper Limit Threshold',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: deltaController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
              decoration: const InputDecoration(
                labelText: 'Max Instant Delta Threshold (0.0 to disable)',
                hintText: 'e.g. 5.0 (Instantaneous jump threshold)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newLower = double.tryParse(lowerController.text) ?? cp.lowerLimit;
              final newUpper = double.tryParse(upperController.text) ?? cp.upperLimit;
              final newDelta = double.tryParse(deltaController.text) ?? cp.maxChangeThreshold;

              ref.read(criticalParamsProvider.notifier).saveCriticalParam(
                    cp.copyWith(
                      lowerLimit: newLower,
                      upperLimit: newUpper,
                      maxChangeThreshold: newDelta,
                    ),
                  );
              Navigator.pop(context);
            },
            child: Text(isNew ? 'Add' : 'Save'),
          ),
        ],
      );
    },
  );
}

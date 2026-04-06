import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/page_layout.dart';
import '../providers/tm_state.dart';

class ParameterPicker extends ConsumerStatefulWidget {
  final Function(CellType, String) onSelect;

  const ParameterPicker({super.key, required this.onSelect});

  @override
  ConsumerState<ParameterPicker> createState() => _ParameterPickerState();
}

class _ParameterPickerState extends ConsumerState<ParameterPicker> with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  String _selectedSubsystem = 'ALL';
  final TextEditingController _headerController = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _headerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;
    final filteredParams = ref.watch(filteredParametersProvider((_searchQuery, _selectedSubsystem)));

    final dialogBg = isDark ? const Color(0xFF0D1321) : Colors.white;
    final surfaceBg = isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return FadeTransition(
      opacity: _fadeAnim,
      child: Dialog(
        backgroundColor: dialogBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: SizedBox(
          width: 560,
          height: 660,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── HEADER ──────────────────────────────────────────────────
              _DialogHeader(primary: primary, isDark: isDark, borderColor: borderColor),

              // ── BODY ────────────────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // -- SET HEADER ----------------------------------------
                      _SectionLabel(text: 'Set as Header Cell', isDark: isDark),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _StyledTextField(
                              controller: _headerController,
                              hintText: 'Enter header label (e.g. Power Subsystem)',
                              surfaceBg: surfaceBg,
                              borderColor: borderColor,
                              isDark: isDark,
                              primary: primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          _PrimaryBtn(
                            label: 'Set Header',
                            icon: Icons.title_rounded,
                            color: primary,
                            onPressed: () {
                              widget.onSelect(CellType.header, _headerController.text);
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      _SectionDivider(isDark: isDark),
                      const SizedBox(height: 20),

                      // -- ASSIGN PARAMETER -----------------------------------
                      Row(
                        children: [
                          Expanded(child: _SectionLabel(text: 'Assign Telemetry Parameter', isDark: isDark)),
                          Text(
                            '${filteredParams.length} params',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.white30 : Colors.black.withAlpha(77),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _StyledTextField(
                        hintText: 'Search mnemonics...',
                        prefixIcon: Icons.search_rounded,
                        surfaceBg: surfaceBg,
                        borderColor: borderColor,
                        isDark: isDark,
                        primary: primary,
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                      const SizedBox(height: 12),

                      // -- PARAM LIST ----------------------------------------
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: surfaceBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: filteredParams.isEmpty
                              ? Center(
                                  child: Text(
                                    'No parameters found',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white30 : Colors.black.withAlpha(77),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  itemCount: filteredParams.length,
                                  separatorBuilder: (_, __) => Divider(
                                    height: 1,
                                    color: borderColor,
                                    indent: 16,
                                    endIndent: 16,
                                  ),
                                  itemBuilder: (context, index) {
                                    final p = filteredParams[index];
                                    return _ParamListTile(
                                      mnemonic: p.mnemonic,
                                      units: p.units,
                                      isDark: isDark,
                                      primary: primary,
                                      onTap: () {
                                        widget.onSelect(CellType.parameter, p.mnemonic);
                                        Navigator.pop(context);
                                      },
                                    );
                                  },
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── FOOTER ──────────────────────────────────────────────────
              _DialogFooter(
                isDark: isDark,
                borderColor: borderColor,
                onClear: () {
                  widget.onSelect(CellType.empty, '');
                  Navigator.pop(context);
                },
                onCancel: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUB-COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class _DialogHeader extends StatelessWidget {
  final Color primary;
  final bool isDark;
  final Color borderColor;
  const _DialogHeader({required this.primary, required this.isDark, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: primary.withAlpha(isDark ? 20 : 10),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: primary.withAlpha(isDark ? 40 : 25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.settings_input_component_rounded, color: primary, size: 18),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cell Configuration',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Text(
                'Link telemetry or set a header label',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DialogFooter extends StatelessWidget {
  final bool isDark;
  final Color borderColor;
  final VoidCallback onClear;
  final VoidCallback onCancel;
  const _DialogFooter({required this.isDark, required this.borderColor, required this.onClear, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          // CLEAR BUTTON
          OutlinedButton.icon(
            icon: const Icon(Icons.delete_outline_rounded, size: 15),
            label: const Text('Clear Cell', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              side: const BorderSide(color: Color(0xFFEF4444), width: 1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: onClear,
          ),
          const Spacer(),
          // CANCEL
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.white38 : Colors.black38,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: const Text('Cancel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool isDark;
  const _SectionLabel({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
        color: isDark ? Colors.white60 : Colors.black54,
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  final bool isDark;
  const _SectionDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: isDark ? Colors.white12 : Colors.black12, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'OR',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: isDark ? Colors.white30 : Colors.black.withAlpha(77),
            ),
          ),
        ),
        Expanded(child: Divider(color: isDark ? Colors.white12 : Colors.black12, height: 1)),
      ],
    );
  }
}

class _StyledTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final IconData? prefixIcon;
  final Color surfaceBg;
  final Color borderColor;
  final bool isDark;
  final Color primary;
  final void Function(String)? onChanged;

  const _StyledTextField({
    this.controller,
    required this.hintText,
    this.prefixIcon,
    required this.surfaceBg,
    required this.borderColor,
    required this.isDark,
    required this.primary,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: isDark ? Colors.white : const Color(0xFF0F172A),
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          fontSize: 12.5,
          color: isDark ? Colors.white30 : Colors.black.withAlpha(77),
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 16, color: isDark ? Colors.white38 : Colors.black38)
            : null,
        filled: true,
        fillColor: surfaceBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: primary, width: 1.5)),
      ),
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _PrimaryBtn({required this.label, required this.icon, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 15),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      ),
      onPressed: onPressed,
    );
  }
}

class _ParamListTile extends StatefulWidget {
  final String mnemonic;
  final String units;
  final bool isDark;
  final Color primary;
  final VoidCallback onTap;

  const _ParamListTile({
    required this.mnemonic,
    required this.units,
    required this.isDark,
    required this.primary,
    required this.onTap,
  });

  @override
  State<_ParamListTile> createState() => _ParamListTileState();
}

class _ParamListTileState extends State<_ParamListTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          color: _hovered
              ? (widget.isDark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(4))
              : Colors.transparent,
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: widget.primary.withAlpha(widget.isDark ? 30 : 20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.analytics_outlined, size: 14, color: widget.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      widget.mnemonic,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        fontFamily: 'monospace',
                        color: widget.isDark ? Colors.white.withAlpha(222) : const Color(0xFF1E293B),
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (widget.units.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        '[${widget.units}]',
                        style: TextStyle(
                          fontSize: 10,
                          color: widget.isDark ? Colors.white38 : Colors.black38,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 11,
                color: _hovered
                    ? widget.primary
                    : (widget.isDark ? Colors.white.withAlpha(51) : Colors.black.withAlpha(51)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

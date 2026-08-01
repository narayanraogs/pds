import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/derived_parameter.dart';
import '../providers/derived_state.dart';

void showDerivedParamPanel(BuildContext context, WidgetRef ref) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, anim1, anim2) {
      return const Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Colors.transparent,
          child: DerivedParamPanel(),
        ),
      );
    },
    transitionBuilder: (context, anim1, anim2, child) {
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
        child: child,
      );
    },
  );
}

class DerivedParamPanel extends ConsumerStatefulWidget {
  const DerivedParamPanel({super.key});
  @override
  ConsumerState<DerivedParamPanel> createState() => _DerivedParamPanelState();
}

class _DerivedParamPanelState extends ConsumerState<DerivedParamPanel> {
  DerivedParameter? editingParam;
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D1321) : Colors.white;
    final border = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    
    return Container(
      width: 450,
      decoration: BoxDecoration(
        color: bg,
        border: Border(left: BorderSide(color: border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: border, width: 1)),
            ),
            child: Row(
              children: [
                Icon(Icons.functions_rounded, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'DERIVED PARAMETERS',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  iconSize: 20,
                  color: isDark ? Colors.white54 : Colors.black54,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: editingParam != null
                ? _EditorForm(
                    param: editingParam!,
                    onCancel: () => setState(() => editingParam = null),
                    onSave: (dp) {
                      ref.read(derivedParamProvider.notifier).save(dp);
                      setState(() => editingParam = null);
                    },
                  )
                : _ListView(
                    onEdit: (dp) => setState(() => editingParam = dp),
                    onCreate: () => setState(() => editingParam = DerivedParameter(id: const Uuid().v4(), mnemonic: 'NEW_PARAM', unit: 'V', expression: 'VAR1 * 2')),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ListView extends ConsumerWidget {
  final void Function(DerivedParameter) onEdit;
  final VoidCallback onCreate;

  const _ListView({required this.onEdit, required this.onCreate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncParams = ref.watch(derivedParamProvider);
    final primary = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('CREATE NEW FORMULA'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: onCreate,
          ),
        ),
        Expanded(
          child: asyncParams.when(
            data: (params) {
              if (params.isEmpty) {
                return Center(
                  child: Text('No derived parameters defined yet.', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: params.length,
                separatorBuilder: (c, i) => Divider(color: isDark ? Colors.white12 : Colors.black12, height: 1),
                itemBuilder: (c, i) {
                  final p = params[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(p.mnemonic, style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
                    subtitle: Text(p.expression, style: TextStyle(color: primary, fontFamily: 'monospace', fontSize: 12)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_rounded, size: 16),
                          color: isDark ? Colors.white70 : Colors.black54,
                          onPressed: () => onEdit(p),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_rounded, size: 16),
                          color: Colors.redAccent,
                          onPressed: () => ref.read(derivedParamProvider.notifier).deleteParam(p.id),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => const Center(child: Text('Error loading params')),
          ),
        ),
      ],
    );
  }
}

class _EditorForm extends StatefulWidget {
  final DerivedParameter param;
  final VoidCallback onCancel;
  final void Function(DerivedParameter) onSave;

  const _EditorForm({required this.param, required this.onCancel, required this.onSave});

  @override
  State<_EditorForm> createState() => _EditorFormState();
}
class _EditorFormState extends State<_EditorForm> {
  late TextEditingController _nameCtrl;
  late TextEditingController _unitCtrl;
  late TextEditingController _exprCtrl;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.param.mnemonic);
    _unitCtrl = TextEditingController(text: widget.param.unit);
    _exprCtrl = TextEditingController(text: widget.param.expression);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _unitCtrl.dispose();
    _exprCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyAndSave(BuildContext context) async {
    final exp = _exprCtrl.text.trim();
    if (exp.isEmpty) return;

    setState(() => _isVerifying = true);

    try {
      final String host = Uri.base.host.isEmpty ? "localhost" : Uri.base.host;
      final int port = Uri.base.port == 0 ? 8888 : Uri.base.port;
      final usedPort = identical(0, 0.0) ? 8888 : port; // kDebugMode loose equiv
      final url = Uri.parse('http://$host:$usedPort/api/derived/verify');

      final res = await http.post(url, body: jsonEncode({'expression': exp}));
      if (res.statusCode != 200) {
        final errJson = jsonDecode(res.body);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Syntax Error: ${errJson['error']}'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        setState(() => _isVerifying = false);
        return; // Halt saving
      }

      // Safe to save
      final dp = DerivedParameter(
        id: widget.param.id.isEmpty ? const Uuid().v4() : widget.param.id,
        mnemonic: _nameCtrl.text.trim().toUpperCase(),
        unit: _unitCtrl.text.trim(),
        expression: exp,
      );
      widget.onSave(dp);

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }

    if (mounted) setState(() => _isVerifying = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Label('MNEMONIC NAME'),
          _TextField(controller: _nameCtrl, isDark: isDark),
          const SizedBox(height: 16),
          
          const _Label('UNITS'),
          _TextField(controller: _unitCtrl, isDark: isDark),
          const SizedBox(height: 16),
          
          const _Label('EXPRESSION (Math Formula)'),
          _TextField(controller: _exprCtrl, isDark: isDark, isMonospace: true, maxLines: 3),
          const SizedBox(height: 8),
          Text(
            'Use standard math ops: +, -, *, /, abs(), etc.',
            style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38),
          ),
          
          const Spacer(),
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isVerifying ? null : widget.onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white70 : Colors.black87,
                    side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('CANCEL'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : () => _verifyAndSave(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isVerifying 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('VERIFY & SAVE'),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: isDark ? Colors.white54 : Colors.black54,
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;
  final bool isMonospace;
  final int maxLines;

  const _TextField({
    required this.controller,
    required this.isDark,
    this.isMonospace = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(
        fontFamily: isMonospace ? 'monospace' : null,
        color: isDark ? Colors.white : Colors.black87,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

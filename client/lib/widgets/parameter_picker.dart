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

class _ParameterPickerState extends ConsumerState<ParameterPicker> {
  String _searchQuery = '';
  String _selectedSubsystem = 'ALL';
  final TextEditingController _headerController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final filteredParams = ref.watch(filteredParametersProvider((_searchQuery, _selectedSubsystem)));

    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withAlpha(10),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withAlpha(50))),
        ),
        child: Row(
          children: [
            Icon(Icons.settings_input_component_rounded, color: Theme.of(context).primaryColor, size: 24),
            const SizedBox(width: 16),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CELL CONFIGURATION',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                ),
                Text(
                  'LINK TO TELEMETRY OR SET HEADER',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.blueAccent, letterSpacing: 0.5),
                ),
              ],
            ),
          ],
        ),
      ),
      content: SizedBox(
        width: 550,
        height: 600,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header option
            const Text('SET AS HEADER TEXT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.grey)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _headerController,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Enter title (e.g. POWER SUBSYSTEM)',
                      hintStyle: TextStyle(fontSize: 11, color: Colors.grey.withAlpha(150), fontWeight: FontWeight.w800),
                      filled: true,
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.title_rounded, size: 18),
                  label: const Text('ADD HEADER', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    widget.onSelect(CellType.header, _headerController.text);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Search input
            const Text('ASSIGN TELEMETRY PARAMETER', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.grey)),
            const SizedBox(height: 10),
            TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Colors.blueAccent),
                hintText: 'FILTER MNEMONICS...',
                hintStyle: TextStyle(fontSize: 11, color: Colors.grey.withAlpha(150), fontWeight: FontWeight.w800, letterSpacing: 1),
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 16),
            
            // Virtualized list
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor.withAlpha(100),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor.withAlpha(30)),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filteredParams.length,
                  itemExtent: 48,
                  itemBuilder: (context, index) {
                    final p = filteredParams[index];
                    return InkWell(
                      onTap: () {
                        widget.onSelect(CellType.parameter, p.mnemonic);
                        Navigator.pop(context);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor.withAlpha(20),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(Icons.analytics_outlined, size: 16, color: Theme.of(context).primaryColor),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                p.mnemonic, 
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, fontFamily: 'monospace', letterSpacing: 0.5)
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey.withAlpha(150)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), 
          child: Text('CANCEL', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w900, fontSize: 12))
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.delete_sweep_rounded, size: 18),
          label: const Text('CLEAR CELL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.withAlpha(30),
            foregroundColor: Colors.redAccent,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Colors.redAccent, width: 0.5)),
          ),
          onPressed: () {
            widget.onSelect(CellType.empty, '');
            Navigator.pop(context);
          }, 
        ),
      ],
    );
  }
}

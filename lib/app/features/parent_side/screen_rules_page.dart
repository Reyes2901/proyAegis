import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:times_up_flutter/models/child_model/child_model.dart';
import 'package:times_up_flutter/models/screen_rule_model.dart';
import 'package:times_up_flutter/services/database.dart';

class ScreenRulesPage extends StatelessWidget {
  const ScreenRulesPage({
    required this.childModel,
    required this.database,
    super.key,
  });

  final ChildModel childModel;
  final Database database;

  static Future<void> show(BuildContext context, ChildModel model) async {
    final database = Provider.of<Database>(context, listen: false);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ScreenRulesPage(
          childModel: model,
          database: database,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Screen time rules'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: StreamBuilder<List<ScreenRule>>(
        stream: database.getScreenRulesStream(childModel.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final rules = snapshot.data ?? const <ScreenRule>[];
          if (rules.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No rules yet'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _openEditor(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add rule'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rules.length,
            itemBuilder: (context, index) {
              final rule = rules[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(rule.name),
                  subtitle: Text(
                    '${rule.startTime} – ${rule.endTime}\n'
                    '${_daysLabel(rule.daysOfWeek)} · '
                    '${rule.blockAll ? "Block all" : "Whitelist (${rule.allowedApps.length})"}',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: rule.enabled,
                        onChanged: (v) => _toggleEnabled(context, rule, v),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _openEditor(context, rule: rule);
                          } else if (value == 'delete') {
                            _confirmDelete(context, rule);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _daysLabel(List<int> days) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (days.length == 7) return 'Every day';
    return days.map((d) => names[d - 1]).join(', ');
  }

  Future<void> _toggleEnabled(
    BuildContext context,
    ScreenRule rule,
    bool enabled,
  ) async {
    await database.setScreenRule(
      childModel.id,
      rule.copyWith(enabled: enabled),
    );
  }

  Future<void> _confirmDelete(BuildContext context, ScreenRule rule) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete rule?'),
        content: Text('Remove "${rule.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await database.deleteScreenRule(childModel.id, rule.id);
    }
  }

  Future<void> _openEditor(BuildContext context, {ScreenRule? rule}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _RuleEditorSheet(
        childModel: childModel,
        database: database,
        initial: rule,
      ),
    );
  }
}

class _RuleEditorSheet extends StatefulWidget {
  const _RuleEditorSheet({
    required this.childModel,
    required this.database,
    this.initial,
  });

  final ChildModel childModel;
  final Database database;
  final ScreenRule? initial;

  @override
  State<_RuleEditorSheet> createState() => _RuleEditorSheetState();
}

class _RuleEditorSheetState extends State<_RuleEditorSheet> {
  late final TextEditingController _nameCtrl;
  late TimeOfDay _start;
  late TimeOfDay _end;
  late Set<int> _days;
  late bool _blockAll;
  late Set<String> _allowedApps;
  bool _saving = false;

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameCtrl = TextEditingController(text: initial?.name ?? '');
    _start = _parseTime(initial?.startTime ?? '22:00');
    _end = _parseTime(initial?.endTime ?? '07:00');
    _days = initial?.daysOfWeek.toSet() ?? {1, 2, 3, 4, 5, 6, 7};
    _blockAll = initial?.blockAll ?? true;
    _allowedApps = initial?.allowedApps.toSet() ?? {};
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  TimeOfDay _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 0,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _applyTemplate(String type) {
    setState(() {
      if (type == 'sleep') {
        _nameCtrl.text = 'Dormir';
        _start = const TimeOfDay(hour: 22, minute: 0);
        _end = const TimeOfDay(hour: 7, minute: 0);
        _days = {1, 2, 3, 4, 5, 6, 7};
        _blockAll = true;
        _allowedApps = {};
      } else {
        _nameCtrl.text = 'Estudio';
        _start = const TimeOfDay(hour: 7, minute: 0);
        _end = const TimeOfDay(hour: 15, minute: 0);
        _days = {1, 2, 3, 4, 5};
        _blockAll = false;
        _allowedApps = {
          'com.google.android.calculator',
          'com.duolingo',
        };
      }
    });
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _days.isEmpty) return;
    setState(() => _saving = true);
    try {
      final rule = ScreenRule(
        id: widget.initial?.id ?? '',
        name: name,
        startTime: _formatTime(_start),
        endTime: _formatTime(_end),
        daysOfWeek: _days.toList()..sort(),
        enabled: widget.initial?.enabled ?? true,
        blockAll: _blockAll,
        allowedApps: _blockAll ? const [] : _allowedApps.toList(),
      );
      await widget.database.setScreenRule(widget.childModel.id, rule);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final apps = widget.childModel.appsUsageModel
        .where((a) => a.packageName.isNotEmpty)
        .toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.initial == null ? 'New rule' : 'Edit rule',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (widget.initial == null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Dormir'),
                    onPressed: () => _applyTemplate('sleep'),
                  ),
                  ActionChip(
                    label: const Text('Estudio'),
                    onPressed: () => _applyTemplate('study'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(true),
                    child: Text('Start ${_formatTime(_start)}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(false),
                    child: Text('End ${_formatTime(_end)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Days', style: Theme.of(context).textTheme.titleSmall),
            Wrap(
              spacing: 4,
              children: List.generate(7, (i) {
                final day = i + 1;
                final selected = _days.contains(day);
                return FilterChip(
                  label: Text(_dayLabels[i]),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _days.add(day);
                      } else {
                        _days.remove(day);
                      }
                    });
                  },
                );
              }),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Block all apps'),
              value: _blockAll,
              onChanged: (v) => setState(() => _blockAll = v),
            ),
            if (!_blockAll) ...[
              Text(
                'Allowed apps',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (apps.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Sync the child device to load installed apps.',
                    style: TextStyle(fontSize: 12),
                  ),
                )
              else
                ...apps.map(
                  (app) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _allowedApps.contains(app.packageName),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _allowedApps.add(app.packageName);
                        } else {
                          _allowedApps.remove(app.packageName);
                        }
                      });
                    },
                    title: Text(app.appName),
                    subtitle: Text(
                      app.packageName,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

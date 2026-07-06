import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:times_up_flutter/models/child_model/child_model.dart';
import 'package:times_up_flutter/models/time_rule_model.dart';
import 'package:times_up_flutter/services/api_path.dart';
import 'package:times_up_flutter/services/database.dart';

class TimeLimitPage extends StatefulWidget {
  const TimeLimitPage({
    required this.childModel,
    required this.database,
    required this.packageName,
    required this.appName,
    this.appIcon,
    Key? key,
  }) : super(key: key);

  final ChildModel childModel;
  final Database database;
  final String packageName;
  final String appName;
  final List<int>? appIcon;

  static Future<void> show(
    BuildContext context, {
    required ChildModel childModel,
    required String packageName,
    required String appName,
    List<int>? appIcon,
  }) async {
    final database = Provider.of<Database>(context, listen: false);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TimeLimitPage(
          childModel: childModel,
          database: database,
          packageName: packageName,
          appName: appName,
          appIcon: appIcon,
        ),
      ),
    );
  }

  @override
  State<TimeLimitPage> createState() => _TimeLimitPageState();
}

class _TimeLimitPageState extends State<TimeLimitPage> {
  bool _enabled = false;
  double _limitMinutes = 30;
  int _usedMinutes = 0;
  bool _loading = true;
  bool _saving = false;

  bool get _isTotalLimit => widget.packageName == APIPath.totalTimeRuleId;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final today = DateTime.now();
    if (_isTotalLimit) {
      _usedMinutes =
          await widget.database.getDailyUsageMinutes(widget.childModel.id, today);
    } else {
      final byApp = await widget.database.getDailyUsageByApp(
        widget.childModel.id,
        today,
      );
      _usedMinutes = byApp[widget.packageName] ?? 0;
    }

    final rules = await widget.database
        .getTimeRulesStream(widget.childModel.id)
        .first;
    TimeRule? match;
    for (final rule in rules) {
      if (rule.packageName == widget.packageName) {
        match = rule;
        break;
      }
    }
    if (match != null && match.isEnabled) {
      _enabled = true;
      _limitMinutes = match.dailyLimitMinutes.toDouble();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      if (!_enabled || _limitMinutes <= 0) {
        await widget.database.deleteTimeRule(
          widget.childModel.id,
          widget.packageName,
        );
      } else {
        await widget.database.setTimeRule(
          widget.childModel.id,
          widget.packageName,
          _limitMinutes.round(),
          const [1, 2, 3, 4, 5, 6, 7],
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final limit = _limitMinutes.round();
    final progress = _enabled && limit > 0
        ? (_usedMinutes / limit).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isTotalLimit ? 'Daily screen time' : widget.appName),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_isTotalLimit && widget.appIcon != null)
                    Center(
                      child: Image.memory(
                        Uint8List.fromList(widget.appIcon!),
                        height: 64,
                      ),
                    ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isTotalLimit ? 'Total daily limit' : 'Daily limit',
                        style: theme.textTheme.titleMedium,
                      ),
                      Switch(
                        value: _enabled,
                        onChanged: (v) => setState(() => _enabled = v),
                      ),
                    ],
                  ),
                  if (_enabled) ...[
                    Text(
                      '$limit min / day',
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    Slider(
                      value: _limitMinutes.clamp(5, 180),
                      min: 5,
                      max: 180,
                      divisions: 35,
                      label: '$limit min',
                      onChanged: (v) => setState(() => _limitMinutes = v),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Used today: $_usedMinutes min',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: progress),
                    if (_usedMinutes >= limit && limit > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Limit reached — app blocked on child device',
                          style: TextStyle(color: theme.colorScheme.error),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                  const Spacer(),
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

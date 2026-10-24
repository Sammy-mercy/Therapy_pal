import 'package:flutter/material.dart';
import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/tokens.dart';
import '../../widgets/ui.dart';

/// Bottom sheet to add a regimen item. Used by patients (self-added) and clinicians (assigned).
Future<bool> showRegimenSheet(BuildContext context, {required String title, required Future<void> Function(Json body) onSubmit}) async {
  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: TP.ground,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _RegimenSheet(title: title, onSubmit: onSubmit),
  );
  return done == true;
}

class _RegimenSheet extends StatefulWidget {
  const _RegimenSheet({required this.title, required this.onSubmit});
  final String title;
  final Future<void> Function(Json body) onSubmit;

  @override
  State<_RegimenSheet> createState() => _RegimenSheetState();
}

class _RegimenSheetState extends State<_RegimenSheet> {
  final _name = TextEditingController();
  final _strength = TextEditingController();
  final _schedule = TextEditingController();
  final _note = TextEditingController();
  String _type = 'medication';
  final List<String> _times = [];
  String? _nameErr, _timesErr, _formErr;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _strength, _schedule, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _addTime() async {
    final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 8, minute: 0));
    if (t == null) return;
    final v = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    if (_times.contains(v)) return;
    setState(() {
      _times
        ..add(v)
        ..sort();
      _timesErr = null;
    });
  }

  Future<void> _save() async {
    final nameBad = _name.text.trim().length < 2;
    final timesBad = _times.isEmpty;
    setState(() {
      _nameErr = nameBad ? 'Enter a name.' : null;
      _timesErr = timesBad ? 'Add at least one time.' : null;
      _formErr = null;
    });
    if (nameBad || timesBad) return;
    setState(() => _busy = true);
    try {
      await widget.onSubmit({
        'name': _name.text.trim(),
        'strength': _strength.text.trim(),
        'type': _type,
        'times': _times,
        if (_schedule.text.trim().isNotEmpty) 'schedule': _schedule.text.trim(),
        'note': _note.text.trim(),
        ...nowQuery(),
      });
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _formErr = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget gap() => const SizedBox(height: 16);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: TP.line, borderRadius: BorderRadius.circular(99)))),
          const SizedBox(height: 16),
          Text(widget.title, style: tpText(20, w: FontWeight.w700, ls: -0.4)),
          const SizedBox(height: 18),
          Seg(options: const [('medication', 'Medication'), ('therapy', 'Therapy')], value: _type, onChanged: (v) => setState(() => _type = v)),
          gap(),
          TpField(label: 'Name', controller: _name, error: _nameErr, hint: _type == 'medication' ? 'e.g. Ibuprofen' : 'e.g. Ankle Exercises'),
          gap(),
          TpField(label: _type == 'medication' ? 'Strength' : 'Detail', controller: _strength, optional: true, hint: _type == 'medication' ? 'e.g. 200 mg' : 'e.g. 15 min set'),
          gap(),
          Text('Times each day', style: tpText(13, w: FontWeight.w700, color: TP.ink2)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in _times)
              InputChip(
                label: Text(fmtTime(t), style: tpText(13, w: FontWeight.w600, color: TP.primary700)),
                backgroundColor: TP.primary050,
                side: BorderSide.none,
                deleteIconColor: TP.primary700,
                onDeleted: () => setState(() => _times.remove(t)),
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16, color: TP.primary),
              label: Text('Add time', style: tpText(13, w: FontWeight.w600, color: TP.primary)),
              backgroundColor: TP.surface,
              side: const BorderSide(color: TP.line),
              onPressed: _addTime,
            ),
          ]),
          if (_timesErr != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_timesErr!, style: tpText(12.5, w: FontWeight.w600, color: TP.danger))),
          gap(),
          TpField(label: 'Schedule description', controller: _schedule, optional: true, hint: 'e.g. 3 times daily, after meals'),
          gap(),
          TpField(label: 'Note', controller: _note, optional: true, maxLines: 3),
          if (_formErr != null) ...[
            gap(),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: TP.dangerBg, borderRadius: BorderRadius.circular(TP.radiusSm)),
              child: Text(_formErr!, style: tpText(13.5, w: FontWeight.w600, color: TP.danger)),
            ),
          ],
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: TpButton('Cancel', kind: BtnKind.ghost, onPressed: () => Navigator.of(context).pop(false))),
            const SizedBox(width: 8),
            Expanded(child: TpButton('Save', onPressed: _save, loading: _busy)),
          ]),
        ]),
      ),
    );
  }
}

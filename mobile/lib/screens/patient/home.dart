import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/responsive.dart';
import '../../core/tokens.dart';
import '../../state/session.dart';
import '../../widgets/charts.dart';
import '../../widgets/page.dart';
import '../../widgets/ui.dart';
import 'regimen_sheet.dart';

List<Json> _list(dynamic v) => (v as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

class _HomeData {
  _HomeData(this.regimens, this.today, this.adherence);
  final List<Json> regimens;
  final Json today;
  final Json adherence;
}

Future<_HomeData> _loadHome(Api api) async {
  final r = await Future.wait<Json>([api.get('/patient/regimens'), api.get('/patient/today', withNow: true), api.get('/patient/adherence', withNow: true)]);
  return _HomeData(_list(r[0]['regimens']), r[1], r[2]);
}

Future<void> _addRegimen(BuildContext context, Api api, Future<void> Function() reload) async {
  final ok = await showRegimenSheet(context, title: 'Add to your regimen', onSubmit: (body) => api.post('/patient/regimens', body));
  if (ok) {
    await reload();
    if (context.mounted) toast(context, 'Regimen item added');
  }
}

String _initialsOf(String name) =>
    name.replaceFirst(RegExp(r'^Dr\.?\s+', caseSensitive: false), '').split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();

class PatientHomePage extends StatelessWidget {
  const PatientHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<Api>();
    final session = context.watch<Session>();
    final badges = context.watch<Badges>();
    final name = firstName(session.name);
    final compact = context.isCompact;
    return Loader<_HomeData>(
      load: () => _loadHome(api),
      loadingHeader: PageHeader(title: '${greeting()}, $name', avatar: compact ? ((session.user?['initials'] as String?) ?? '') : null),
      builder: (context, data, reload) {
        final doses = _list(data.today['doses']);
        final taken = (data.today['taken'] as num).toInt();
        final total = doses.length;
        final pct = total == 0 ? 0 : ((taken / total) * 100).round();
        final next = data.today['next'] as Map?;
        final activeCount = data.regimens.where((r) => r['active'] == true).length;
        final rate30 = (data.adherence['rate'] as num?)?.toInt();

        Future<void> refreshAll() async {
          await reload();
          if (context.mounted) context.read<Badges>().refresh('patient');
        }

        final hero = TpCard(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('TODAY\u2019S PROGRESS', style: eyebrow),
                  const SizedBox(height: 2),
                  Text.rich(TextSpan(children: [
                    TextSpan(text: '$taken ', style: tpText(30, w: FontWeight.w700, ls: -0.9)),
                    TextSpan(text: 'of $total doses', style: tpText(14, w: FontWeight.w600, color: TP.muted)),
                  ])),
                ]),
              ),
              Text('$pct%', style: tpText(22, w: FontWeight.w700, color: TP.primary)),
            ]),
            const SizedBox(height: 12),
            ProgressBar(pct),
            if (next != null) ...[
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.schedule, size: 16, color: TP.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: 'Next: ', style: tpText(13, color: TP.ink2)),
                    TextSpan(text: '${next['label']}', style: tpText(13, w: FontWeight.w700, color: TP.ink2)),
                    TextSpan(text: ' at ${fmtTime(next['slot'] as String)}', style: tpText(13, color: TP.ink2)),
                  ])),
                ),
              ]),
            ] else if (total > 0) ...[
              const SizedBox(height: 12),
              Text("You're all caught up for today.", style: tpText(13, color: TP.ink2)),
            ],
          ]),
        );

        final regimenList = data.regimens.isEmpty
            ? const EmptyCard('No regimen items yet.\nTap Add New to start.')
            : (compact
                ? Column(children: [for (final r in data.regimens) Padding(padding: const EdgeInsets.only(bottom: 8), child: RegimenCard(regimen: r, onChanged: refreshAll))])
                : GridList(minTileWidth: 380, children: [for (final r in data.regimens) RegimenCard(regimen: r, onChanged: refreshAll)]));
        final addBtn = TpButton('Add New', icon: Icons.add, kind: BtnKind.ghost, small: true, onPressed: () => _addRegimen(context, api, refreshAll));

        final dosesList = doses.isEmpty
            ? const EmptyCard('No doses scheduled today.')
            : Column(children: [for (final d in doses) Padding(padding: const EdgeInsets.only(bottom: 8), child: DoseRow(dose: d, onChanged: refreshAll))]);

        final header = PageHeader(
          avatar: compact ? ((session.user?['initials'] as String?) ?? '') : null,
          title: '${greeting()}, $name',
          sub: compact ? '${longToday()} \u00b7 $taken of $total doses logged' : '$taken of $total doses logged today',
          actions: [if (compact) IconBox(icon: Icons.notifications_none, badge: badges.alerts, label: 'Notifications', onTap: () => context.go('/patient/alerts'))],
        );

        if (compact) {
          return PageScaffold(
            onRefresh: refreshAll,
            header: header,
            children: [
              hero,
              SectionHead('Your regimen', trailing: addBtn),
              regimenList,
              SectionHead('Today\u2019s doses', trailing: Text('$taken of $total taken', style: mutedSm)),
              dosesList,
            ],
          );
        }

        return PageScaffold(
          onRefresh: refreshAll,
          header: header,
          children: [
            StatStrip([
              StatTile('$pct%', '$taken of $total doses logged today'),
              StatTile(rate30 == null ? '\u2014' : '$rate30%', '30-day adherence'),
              StatTile('$activeCount', 'Active regimen ${activeCount == 1 ? 'item' : 'items'}'),
              StatTile('${badges.alerts}', 'Unread alerts'),
            ]),
            const SizedBox(height: 4),
            MainAside(
              main: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SectionHead('Today\u2019s doses', trailing: Text('$taken of $total taken', style: mutedSm)),
                dosesList,
              ]),
              aside: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionHead('Progress'),
                hero,
                const SectionHead('Adherence insights'),
                _InsightsCard(adherence: data.adherence),
                if (session.user?['clinician'] is Map) ...[
                  const SizedBox(height: 16),
                  _CareTeamCard(clinician: Map<String, dynamic>.from(session.user!['clinician'] as Map)),
                ],
              ]),
            ),
            SectionHead('Your regimen', trailing: addBtn),
            regimenList,
          ],
        );
      },
    );
  }
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.adherence});
  final Json adherence;

  @override
  Widget build(BuildContext context) {
    final weekly = (adherence['weekly'] as List).map((e) => (e as num?)?.toInt()).toList();
    final slips = _list(adherence['slips']);
    final worst = slips.isEmpty ? null : (slips.toList()..sort((a, b) => (b['missed'] as num).compareTo(a['missed'] as num))).first;
    final hasSlip = worst != null && (worst['missed'] as num) > 0;
    return TpCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('6-week trend', style: tpText(13, w: FontWeight.w700, color: TP.ink2))),
          Text('% on time', style: mutedSm),
        ]),
        const SizedBox(height: 12),
        BarChart(values: weekly, labels: [for (var i = 0; i < weekly.length; i++) 'W${i + 1}'], height: 96),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: TP.primary050, borderRadius: BorderRadius.circular(TP.radiusSm)),
          child: Text(
            hasSlip ? 'Most missed doses: ${worst['label']} (${worst['missed']}).' : 'No missed doses in the last 30 days. Keep it up.',
            style: tpText(12.5, w: FontWeight.w600, color: TP.primary700, h: 1.45),
          ),
        ),
      ]),
    );
  }
}

class _CareTeamCard extends StatelessWidget {
  const _CareTeamCard({required this.clinician});
  final Json clinician;

  @override
  Widget build(BuildContext context) {
    final name = '${clinician['name']}';
    return TpCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Avatar(_initialsOf(name), size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: rowTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('Your care team', style: rowSub),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        TpButton('Message $name', icon: Icons.chat_bubble_outline, small: true, block: true, onPressed: () => context.go('/patient/profile/messages')),
      ]),
    );
  }
}

class RegimenCard extends StatefulWidget {
  const RegimenCard({super.key, required this.regimen, required this.onChanged});
  final Json regimen;
  final Future<void> Function() onChanged;

  @override
  State<RegimenCard> createState() => _RegimenCardState();
}

class _RegimenCardState extends State<RegimenCard> {
  bool _open = false;
  bool _busy = false;

  Future<void> _logDose() async {
    final api = context.read<Api>();
    setState(() => _busy = true);
    try {
      await api.post('/patient/doses', {'regimenId': widget.regimen['id'], ...nowQuery()});
      await widget.onChanged();
      if (mounted) toast(context, 'Dose logged');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle() async {
    final api = context.read<Api>();
    final active = widget.regimen['active'] == true;
    setState(() => _busy = true);
    try {
      await api.patch('/patient/regimens/${widget.regimen['id']}', {'active': !active});
      await widget.onChanged();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.regimen;
    final therapy = r['type'] == 'therapy';
    final active = r['active'] == true;
    final times = (r['times'] as List).map((t) => fmtTime(t as String)).join(' \u00b7 ');
    final title = '${r['name']} ${r['strength'] ?? ''}'.trim();
    return TpCard(
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(TP.radius),
          onTap: () => setState(() => _open = !_open),
          child: Semantics(
            button: true,
            expanded: _open,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(children: [
                TypeIcon(therapy ? Icons.accessibility_new : Icons.medication_outlined, kind: therapy ? IconKind.therapy : IconKind.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: rowTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('${r['schedule']}', style: rowSub, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
                const SizedBox(width: 8),
                Tag(active ? 'Active' : 'Paused', kind: active ? TagKind.active : TagKind.inactive),
                const SizedBox(width: 4),
                AnimatedRotation(turns: _open ? .5 : 0, duration: TP.speed, child: const Icon(Icons.expand_more, color: TP.muted, size: 20)),
              ]),
            ),
          ),
        ),
        AnimatedSize(
          duration: TP.speed,
          curve: TP.ease,
          alignment: Alignment.topCenter,
          child: !_open
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    KvList([('Prescriber', '${r['prescriber']}'), ('Started', prettyDate('${r['started']}')), ('Times', times)]),
                    if ('${r['note']}'.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('${r['note']}', style: tpText(13.5, color: TP.ink2, h: 1.55)),
                    ],
                    const SizedBox(height: 14),
                    Row(children: [
                      if (active) ...[
                        Expanded(child: TpButton('Log a dose', icon: Icons.check, small: true, onPressed: _logDose, loading: _busy)),
                        const SizedBox(width: 8),
                      ],
                      Expanded(child: TpButton(active ? 'Pause' : 'Resume', kind: BtnKind.ghost, small: true, onPressed: _busy ? null : _toggle)),
                    ]),
                  ]),
                ),
        ),
      ]),
    );
  }
}

class DoseRow extends StatefulWidget {
  const DoseRow({super.key, required this.dose, required this.onChanged});
  final Json dose;
  final Future<void> Function() onChanged;

  @override
  State<DoseRow> createState() => _DoseRowState();
}

class _DoseRowState extends State<DoseRow> {
  bool _busy = false;

  Future<void> _take() async {
    final api = context.read<Api>();
    setState(() => _busy = true);
    try {
      await api.post('/patient/doses', {'regimenId': widget.dose['regimenId'], 'slot': widget.dose['slot'], ...nowQuery()});
      await widget.onChanged();
      if (mounted) toast(context, 'Dose logged');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.dose;
    final status = d['status'] as String;
    final slot = fmtTime(d['slot'] as String);
    final (Widget mark, String sub) = switch (status) {
      'taken' => (_mark(TP.success, Icons.check, solid: true), 'Taken \u00b7 ${fmtTime(d['loggedTime'] as String?, pad: true)}'),
      'due' => (_mark(TP.primary, Icons.schedule, solid: true), 'Due now \u00b7 scheduled $slot'),
      'missed' => (_mark(TP.danger, Icons.error_outline, bg: TP.dangerBg), 'Missed \u00b7 scheduled $slot'),
      _ => (_mark(TP.muted, Icons.schedule, dashed: true), 'Upcoming \u00b7 $slot'),
    };
    final Widget trailing = switch (status) {
      'taken' => Tag(fmtTime(d['loggedTime'] as String?, pad: true), kind: TagKind.active),
      'due' => TpButton('Take now', small: true, onPressed: _take, loading: _busy),
      _ => TpButton('Log', small: true, kind: BtnKind.ghost, onPressed: _take, loading: _busy),
    };
    return RowItem(leading: mark, title: '${d['label']}', subs: [sub], trailing: trailing);
  }

  Widget _mark(Color color, IconData icon, {bool solid = false, bool dashed = false, Color? bg}) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: solid ? color : bg,
        border: dashed ? Border.all(color: const Color(0xFFB9C7CB), width: 1.5) : null,
      ),
      child: Icon(icon, size: 16, color: solid ? Colors.white : color),
    );
  }
}

class PatientRegimenPage extends StatefulWidget {
  const PatientRegimenPage({super.key});

  @override
  State<PatientRegimenPage> createState() => _PatientRegimenPageState();
}

class _PatientRegimenPageState extends State<PatientRegimenPage> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final api = context.read<Api>();
    return Loader<List<Json>>(
      load: () async => _list((await api.get('/patient/regimens'))['regimens']),
      loadingHeader: const PageHeader(title: 'My Regimen'),
      builder: (context, all, reload) {
        final items = all.where((r) {
          final active = r['active'] == true;
          return switch (_filter) {
            'medication' => r['type'] == 'medication' && active,
            'therapy' => r['type'] == 'therapy' && active,
            'paused' => !active,
            _ => true,
          };
        }).toList();
        return PageScaffold(
          onRefresh: reload,
          header: PageHeader(title: 'My Regimen', sub: '${all.where((r) => r['active'] == true).length} active items'),
          children: [
            ChipRow(
              items: const [('all', 'All'), ('medication', 'Medication'), ('therapy', 'Therapy'), ('paused', 'Paused')],
              current: _filter,
              onSelected: (v) => setState(() => _filter = v),
            ),
            SectionHead(plural(items.length, 'item'), top: 16, trailing: TpButton('Add New', icon: Icons.add, kind: BtnKind.ghost, small: true, onPressed: () => _addRegimen(context, api, reload))),
            if (items.isEmpty)
              const EmptyCard('Nothing matches this filter yet.')
            else if (context.isCompact)
              for (final r in items) Padding(padding: const EdgeInsets.only(bottom: 8), child: RegimenCard(regimen: r, onChanged: reload))
            else
              GridList(minTileWidth: 380, children: [for (final r in items) RegimenCard(regimen: r, onChanged: reload)]),
          ],
        );
      },
    );
  }
}

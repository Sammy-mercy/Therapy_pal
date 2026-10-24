import 'dart:async';
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
import '../patient/regimen_sheet.dart';
import '../thread.dart';

List<Json> _list(dynamic v) => (v as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

bool _matches(Json p, String query, String filter) {
  final rate = (p['rate'] as num?)?.toInt();
  if (filter == 'stable' && !(rate != null && rate >= 80)) return false;
  if (filter == 'risk' && !(rate != null && rate < 80)) return false;
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return '${p['name']}'.toLowerCase().contains(q) || '${p['regimen']}'.toLowerCase().contains(q);
}

class _PanelSearch extends StatelessWidget {
  const _PanelSearch({required this.query, required this.onQuery, required this.filter, required this.onFilter, required this.open, required this.onToggle});
  final String query;
  final ValueChanged<String> onQuery;
  final String filter;
  final ValueChanged<String> onFilter;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [
        Expanded(
          child: TextField(
            onChanged: onQuery,
            style: tpText(14.5),
            decoration: InputDecoration(
              hintText: 'Search patients or regimens',
              hintStyle: tpText(14.5, color: const Color(0xFF8A9BA0)),
              prefixIcon: const Icon(Icons.search, size: 18, color: TP.muted),
              filled: true,
              fillColor: TP.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(TP.radiusSm), borderSide: const BorderSide(color: TP.line)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(TP.radiusSm), borderSide: const BorderSide(color: TP.line)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(TP.radiusSm), borderSide: const BorderSide(color: TP.primary, width: 2)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconBox(icon: Icons.tune, label: 'Show filters', onTap: onToggle),
      ]),
      if (open) ...[
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: ChipRow(items: const [('all', 'All patients'), ('stable', 'On track'), ('risk', 'Needs attention')], current: filter, onSelected: onFilter),
        ),
      ],
    ]);
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.n);
  final int n;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
        padding: const EdgeInsets.symmetric(horizontal: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: TP.danger, borderRadius: BorderRadius.circular(99)),
        child: Text('$n', style: tpText(10.5, w: FontWeight.w700, color: Colors.white)),
      );
}

/* -------------------------------------------------------------- dashboard */

class _DashData {
  _DashData(this.patients, this.summary, this.threads);
  final List<Json> patients;
  final Json summary;
  final List<Json> threads;
}

class _PatientTable extends StatelessWidget {
  const _PatientTable(this.rows);
  final List<Json> rows;

  @override
  Widget build(BuildContext context) {
    TextStyle head() => tpText(10.5, w: FontWeight.w700, color: TP.primary700, ls: 0.7);
    return TpCard(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(TP.radius),
        child: LayoutBuilder(builder: (context, c) {
          final showLast = c.maxWidth >= 640;
          return Column(children: [
            Container(
              color: TP.primary050,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                Expanded(flex: 105, child: Text('PATIENT', style: head())),
                Expanded(flex: 130, child: Text('CURRENT REGIMEN', style: head())),
                if (showLast) Expanded(flex: 70, child: Text('LAST LOG', style: head())),
                SizedBox(width: 72, child: Text('ADHERENCE', textAlign: TextAlign.right, style: head())),
              ]),
            ),
            for (var i = 0; i < rows.length; i++)
              InkWell(
                onTap: () => context.go('/clinician/patients/${rows[i]['id']}'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(border: i == rows.length - 1 ? null : const Border(bottom: BorderSide(color: TP.line))),
                  child: Row(children: [
                    Expanded(
                      flex: 105,
                      child: Padding(padding: const EdgeInsets.only(right: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${rows[i]['name']}', style: tpText(14, w: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('${rows[i]['note']}', style: tpText(12, color: TP.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ])),
                    ),
                    Expanded(flex: 130, child: Padding(padding: const EdgeInsets.only(right: 14), child: Text('${rows[i]['regimen']}', style: tpText(12, color: TP.muted), maxLines: 2, overflow: TextOverflow.ellipsis))),
                    if (showLast) Expanded(flex: 70, child: Text(_lastLog(rows[i]['lastLog']), style: tpText(12, color: TP.muted), maxLines: 2, overflow: TextOverflow.ellipsis)),
                    SizedBox(width: 72, child: Align(alignment: Alignment.centerRight, child: RatePill((rows[i]['rate'] as num?)?.toInt()))),
                  ]),
                ),
              ),
          ]);
        }),
      ),
    );
  }
}

class ClinicianDashboardPage extends StatefulWidget {
  const ClinicianDashboardPage({super.key});

  @override
  State<ClinicianDashboardPage> createState() => _ClinicianDashboardPageState();
}

class _ClinicianDashboardPageState extends State<ClinicianDashboardPage> {
  String _query = '';
  String _filter = 'all';
  bool _filtersOpen = false;

  @override
  Widget build(BuildContext context) {
    final api = context.read<Api>();
    final session = context.watch<Session>();
    final badges = context.watch<Badges>();
    final u = session.user ?? {};
    final compact = context.isCompact;
    final header = compact
        ? PageHeader(
            avatar: '${u['initials'] ?? ''}',
            title: '${u['name'] ?? ''}',
            sub: '${u['specialization'] ?? ''}',
            actions: [IconBox(icon: Icons.chat_bubble_outline, badge: badges.messages, label: 'Messages', onTap: () => context.go('/clinician/messages'))],
          )
        : PageHeader(title: 'Dashboard', sub: '${u['name'] ?? ''} \u00b7 ${u['specialization'] ?? ''}');
    return Loader<_DashData>(
      load: () async {
        final r = await Future.wait<Json>([api.get('/clinician/patients', withNow: true), api.get('/messages/threads')]);
        return _DashData(_list(r[0]['patients']), Map<String, dynamic>.from(r[0]['summary'] as Map), _list(r[1]['threads']));
      },
      loadingHeader: header,
      builder: (context, d, reload) {
        final shown = d.patients.where((p) => _matches(p, _query, _filter)).toList();
        final avg = (d.summary['avgAdherence'] as num?)?.toInt();
        final withMessages = d.threads.where((t) => t['last'] != null).toList();

        final search = _PanelSearch(
          query: _query,
          onQuery: (v) => setState(() => _query = v),
          filter: _filter,
          onFilter: (v) => setState(() => _filter = v),
          open: _filtersOpen,
          onToggle: () => setState(() => _filtersOpen = !_filtersOpen),
        );
        final table = shown.isEmpty ? EmptyCard(d.patients.isEmpty ? 'No patients in your panel yet.' : 'No patients match this search.') : _PatientTable(shown);

        Widget threadRow(Json t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RowItem(
                leading: Avatar('${t['initials']}'),
                title: '${t['name']}',
                subs: ['${(t['last'] as Map)['text']}'],
                subLines: 2,
                trailing: (t['unread'] as num) > 0 ? _CountBadge((t['unread'] as num).toInt()) : const Icon(Icons.chevron_right, color: TP.muted),
                onTap: () => context.go('/clinician/messages/${t['patientId']}'),
              ),
            );

        Future<void> refreshAll() async {
          await reload();
          if (context.mounted) context.read<Badges>().refresh('clinician');
        }

        if (compact) {
          return PageScaffold(
            onRefresh: refreshAll,
            header: header,
            children: [
              StatStrip([
                StatTile('${d.summary['total']}', 'Patients'),
                StatTile(avg == null ? '\u2014' : '$avg%', 'Avg adherence'),
                StatTile('${d.summary['needsAttention']}', 'Needs attention'),
              ]),
              SectionHead('Patient Overview', trailing: Text(plural(d.patients.length, 'patient'), style: mutedSm)),
              search,
              const SizedBox(height: 12),
              table,
              SectionHead('Messages', trailing: LinkBtn('Open inbox', onTap: () => context.go('/clinician/messages'))),
              if (withMessages.isEmpty) const EmptyCard('No conversations yet.') else threadRow(withMessages.first),
            ],
          );
        }

        return PageScaffold(
          onRefresh: refreshAll,
          header: header,
          children: [
            StatStrip([
              StatTile('${d.summary['total']}', 'Patients under care'),
              StatTile(avg == null ? '\u2014' : '$avg%', 'Average adherence'),
              StatTile('${d.summary['needsAttention']}', 'Need attention'),
              StatTile('${badges.messages}', 'Unread messages'),
            ]),
            MainAside(
              main: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SectionHead('Patient Overview', trailing: Text(plural(d.patients.length, 'patient'), style: mutedSm)),
                search,
                const SizedBox(height: 12),
                table,
              ]),
              aside: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SectionHead('Recent messages', trailing: LinkBtn('Open inbox', onTap: () => context.go('/clinician/messages'))),
                if (withMessages.isEmpty) const EmptyCard('No conversations yet.') else for (final t in withMessages.take(5)) threadRow(t),
              ]),
            ),
          ],
        );
      },
    );
  }
}

/* --------------------------------------------------------------- patients */

class ClinicianPatientsPage extends StatefulWidget {
  const ClinicianPatientsPage({super.key});

  @override
  State<ClinicianPatientsPage> createState() => _ClinicianPatientsPageState();
}

class _ClinicianPatientsPageState extends State<ClinicianPatientsPage> {
  String _query = '';
  String _filter = 'all';
  bool _filtersOpen = false;

  Future<void> _link(BuildContext context, Api api, Future<void> Function() reload) async {
    final ctl = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TP.surface,
        title: Text('Add a patient', style: tpText(18, w: FontWeight.w700)),
        content: TpField(label: 'Patient email', controller: ctl, keyboard: TextInputType.emailAddress, hint: 'Their Therapy Pal account email'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    ctl.dispose();
    if (email == null || email.isEmpty) return;
    try {
      await api.post('/clinician/patients/link', {'email': email});
      await reload();
      if (context.mounted) toast(context, 'Patient added to your panel');
    } on ApiException catch (e) {
      if (context.mounted) toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = context.read<Api>();
    return Loader<List<Json>>(
      load: () async => _list((await api.get('/clinician/patients', withNow: true))['patients']),
      loadingHeader: const PageHeader(title: 'Patients'),
      builder: (context, patients, reload) {
        final shown = patients.where((p) => _matches(p, _query, _filter)).toList();
        return PageScaffold(
          onRefresh: reload,
          header: PageHeader(
            title: 'Patients',
            sub: '${patients.length} in your panel',
            actions: [IconBox(icon: Icons.person_add_alt, label: 'Add patient', onTap: () => _link(context, api, reload))],
          ),
          children: [
            _PanelSearch(
              query: _query,
              onQuery: (v) => setState(() => _query = v),
              filter: _filter,
              onFilter: (v) => setState(() => _filter = v),
              open: _filtersOpen,
              onToggle: () => setState(() => _filtersOpen = !_filtersOpen),
            ),
            const SizedBox(height: 12),
            if (shown.isEmpty) EmptyCard(patients.isEmpty ? 'No patients in your panel yet.' : 'No patients match this search.'),
            GridList(minTileWidth: 380, children: [
              for (final p in shown)
                RowItem(
                  leading: Avatar('${p['initials']}'),
                  title: '${p['name']}',
                  subs: ['${p['regimen']}', 'Last log ${_lastLog(p['lastLog'])}'],
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [RatePill((p['rate'] as num?)?.toInt()), const SizedBox(width: 4), const Icon(Icons.chevron_right, color: TP.muted)]),
                  onTap: () => context.go('/clinician/patients/${p['id']}'),
                ),
            ]),
          ],
        );
      },
    );
  }
}

String _lastLog(dynamic l) {
  if (l is! Map) return 'never';
  return '${dayLabel('${l['day']}').toLowerCase()}, ${fmtTime('${l['time']}', pad: true)}';
}

class ClinicianPatientPage extends StatelessWidget {
  const ClinicianPatientPage({super.key, required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context) {
    final api = context.read<Api>();
    return Loader<Json>(
      load: () => api.get('/clinician/patients/$patientId', withNow: true),
      loadingHeader: const PageHeader(title: 'Patient', backTo: '/clinician/patients'),
      builder: (context, d, reload) {
        final p = Map<String, dynamic>.from(d['patient'] as Map);
        final regimens = _list(d['regimens']);
        final rate = (p['rate'] as num?)?.toInt();
        final since = DateTime.tryParse('${p['since']}')?.toLocal();

        final ring = TpCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Column(children: [
            Ring(pct: rate, caption: 'adherence'),
            const SizedBox(height: 16),
            StatStrip([
              StatTile(p['age'] == null ? '\u2014' : '${p['age']}', 'Age'),
              StatTile(since == null ? '\u2014' : '${since.year}', 'Under care'),
              StatTile(rate == null ? 'No data' : rate >= 80 ? 'On track' : 'At risk', 'Status'),
            ]),
          ]),
        );
        final regimenSection = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionHead('Current regimen'),
          if (regimens.isEmpty) const EmptyCard('No regimen items yet.'),
          for (final r in regimens)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RowItem(
                leading: TypeIcon(r['type'] == 'therapy' ? Icons.accessibility_new : Icons.medication_outlined, kind: r['type'] == 'therapy' ? IconKind.therapy : IconKind.primary),
                title: '${r['name']} ${r['strength'] ?? ''}'.trim(),
                subs: ['${r['schedule']}'],
                trailing: Tag(r['active'] == true ? 'Active' : 'Paused', kind: r['active'] == true ? TagKind.active : TagKind.inactive),
              ),
            ),
          const SizedBox(height: 10),
          TpButton('Message patient', icon: Icons.chat_bubble_outline, block: true, onPressed: () => context.go('/clinician/messages/${p['id']}')),
          const SizedBox(height: 10),
          TpButton('Assign regimen item', icon: Icons.add, kind: BtnKind.ghost, block: true, onPressed: () async {
            final ok = await showRegimenSheet(context, title: 'Assign to ${firstName('${p['name']}')}', onSubmit: (body) => api.post('/clinician/patients/${p['id']}/regimens', body));
            if (ok) {
              await reload();
              if (context.mounted) toast(context, 'Regimen item assigned');
            }
          }),
        ]);
        final header = PageHeader(title: '${p['name']}', sub: '${p['note']}', backTo: '/clinician/patients');

        if (context.isCompact) {
          return PageScaffold(onRefresh: reload, header: header, children: [ring, regimenSection]);
        }
        return PageScaffold(
          onRefresh: reload,
          maxWidth: 1100,
          header: header,
          children: [
            MainAside(
              main: regimenSection,
              aside: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const SectionHead('Adherence'), ring]),
            ),
          ],
        );
      },
    );
  }
}

/* --------------------------------------------------------------- messages */

/// Inbox. Phone: list, then full-screen thread. Tablet/laptop: list and thread side by side.
class ClinicianMessagesPage extends StatefulWidget {
  const ClinicianMessagesPage({super.key, this.selectedId});
  final String? selectedId;

  @override
  State<ClinicianMessagesPage> createState() => _ClinicianMessagesPageState();
}

class _ClinicianMessagesPageState extends State<ClinicianMessagesPage> {
  Json? _data;
  Object? _error;
  bool _loading = true;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 12), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final api = context.read<Api>();
    final badges = context.read<Badges>();
    try {
      final d = await api.get('/messages/threads');
      if (!mounted) return;
      setState(() {
        _data = d;
        _error = null;
        _loading = false;
      });
      badges.refresh('clinician');
    } catch (e) {
      if (!mounted || (silent && _data != null)) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = context.isWide;
    final selected = widget.selectedId;
    if (!wide && selected != null) {
      return ThreadPage(key: ValueKey(selected), patientId: selected, backTo: '/clinician/messages', subtitle: 'Patient conversation');
    }

    final threads = _data == null ? <Json>[] : _list(_data!['threads']);
    final unread = _data == null ? 0 : (_data!['unread'] as num).toInt();
    final header = PageHeader(title: 'Messages', sub: _data == null ? null : '${plural(threads.length, 'conversation')}${unread > 0 ? ' \u00b7 $unread unread' : ''}');

    if (_data == null) {
      return SafeArea(
        bottom: false,
        child: Column(children: [
          header,
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: TP.primary))
                : ErrorBlock(
                    message: _error is ApiException ? (_error as ApiException).message : 'Something went wrong.',
                    onRetry: () {
                      setState(() => _loading = true);
                      _load();
                    },
                  ),
          ),
        ]),
      );
    }

    Widget row(Json t) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: RowItem(
            selected: wide && t['patientId'] == selected,
            leading: Avatar('${t['initials']}'),
            title: '${t['name']}',
            subs: [t['last'] == null ? 'No messages yet' : '${(t['last'] as Map)['from'] == 'me' ? 'You: ' : ''}${(t['last'] as Map)['text']}'],
            trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (t['last'] != null) Text(shortTime('${(t['last'] as Map)['createdAt']}'), style: rowSub),
              if ((t['unread'] as num) > 0) ...[const SizedBox(height: 6), _CountBadge((t['unread'] as num).toInt())],
            ]),
            onTap: () => context.go('/clinician/messages/${t['patientId']}'),
          ),
        );

    if (!wide) {
      return PageScaffold(
        onRefresh: _load,
        header: header,
        children: [if (threads.isEmpty) const EmptyCard('No conversations yet.'), for (final t in threads) row(t)],
      );
    }

    final gutter = pageGutter(context.screenSize);
    final listWidth = context.screenSize == ScreenSize.expanded ? 360.0 : 300.0;
    return SafeArea(
      bottom: false,
      child: Column(children: [
        Padding(padding: EdgeInsets.symmetric(horizontal: gutter - 16), child: header),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(gutter, 4, gutter, gutter),
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(
                width: listWidth,
                child: threads.isEmpty ? const EmptyCard('No conversations yet.') : ListView(children: [for (final t in threads) row(t)]),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: selected == null
                    ? TpCard(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              const TypeIcon(Icons.chat_bubble_outline),
                              const SizedBox(height: 12),
                              Text('Select a conversation', style: rowTitle),
                              const SizedBox(height: 4),
                              Text('Choose a patient on the left to read and reply.', style: rowSub, textAlign: TextAlign.center),
                            ]),
                          ),
                        ),
                      )
                    : ThreadPage(key: ValueKey(selected), patientId: selected, subtitle: 'Patient conversation', embedded: true),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

/* -------------------------------------------------------------- analytics */

class ClinicianAnalyticsPage extends StatelessWidget {
  const ClinicianAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<Api>();
    return Loader<Json>(
      load: () => api.get('/clinician/analytics', withNow: true),
      loadingHeader: const PageHeader(title: 'Analytics'),
      builder: (context, a, reload) {
        final by = _list(a['byPatient']);
        final trend = (a['trend'] as List).map((e) => (e as num?)?.toInt()).toList();
        final slips = _list(a['slips']);
        final missed = (a['missed'] as num).toInt();
        final avg = (a['avgAdherence'] as num?)?.toInt();

        final stats = StatStrip([
          StatTile(avg == null ? '\u2014' : '$avg%', 'Avg adherence'),
          StatTile('${a['onTrack']}/${a['patients']}', 'On track'),
          StatTile('$missed', 'Missed doses'),
        ]);
        final byCard = TpCard(
          padding: const EdgeInsets.all(16),
          child: by.isEmpty
              ? Text('No patients yet.', style: rowSub)
              : BarChart(values: [for (final p in by) (p['rate'] as num?)?.toInt()], labels: [for (final p in by) firstName('${p['name']}')]),
        );
        final trendCard = TpCard(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16), child: Sparkline(trend));
        final slipsCard = TpCard(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            for (var i = 0; i < slips.length; i++) ...[
              if (i > 0) const SizedBox(height: 14),
              MeterRow(label: '${slips[i]['label']}', count: (slips[i]['missed'] as num).toInt(), total: missed),
            ],
          ]),
        );
        final header = const PageHeader(title: 'Analytics', sub: 'Panel overview \u00b7 last 30 days');
        final byHead = SectionHead('Adherence by patient', trailing: Text('Target 80%', style: mutedSm));
        final trendHead = SectionHead('Panel trend', trailing: Text('${trend.length} weeks', style: mutedSm));

        if (context.isCompact) {
          return PageScaffold(
            onRefresh: reload,
            header: header,
            children: [stats, byHead, byCard, trendHead, trendCard, const SectionHead('When doses are missed'), slipsCard],
          );
        }
        return PageScaffold(
          onRefresh: reload,
          header: header,
          children: [
            stats,
            MainAside(
              main: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [byHead, byCard, trendHead, trendCard]),
              aside: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const SectionHead('When doses are missed'), slipsCard]),
            ),
          ],
        );
      },
    );
  }
}

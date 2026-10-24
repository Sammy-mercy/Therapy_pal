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

List<Json> _list(dynamic v) => (v as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

/* ------------------------------------------------------------------ logs */

class PatientLogsPage extends StatelessWidget {
  const PatientLogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<Api>();
    return Loader<List<Json>>(
      load: () async => _list((await api.get('/patient/logs', withNow: true))['logs']),
      loadingHeader: const PageHeader(title: 'Logs'),
      builder: (context, logs, reload) {
        final days = <String, List<Json>>{};
        for (final l in logs) {
          days.putIfAbsent(l['day'] as String, () => []).add(l);
        }
        return PageScaffold(
          onRefresh: reload,
          maxWidth: 880,
          header: const PageHeader(title: 'Logs', sub: 'Last 14 days'),
          children: [
            if (logs.isEmpty) const EmptyCard('No dose events yet.'),
            for (final e in days.entries) ...[
              SectionHead(dayLabel(e.key), top: 16, trailing: Text(plural(e.value.length, 'event'), style: mutedSm)),
              for (final l in e.value)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RowItem(
                    leading: TypeIcon(l['status'] == 'missed' ? Icons.error_outline : Icons.check, kind: l['status'] == 'missed' ? IconKind.danger : IconKind.primary),
                    title: '${l['label']}',
                    subs: ['${l['status'] == 'missed' ? 'Missed' : 'Med taken'} \u00b7 ${fmtTime(l['time'] as String, pad: true)}'],
                    trailing: Tag(l['status'] == 'missed' ? 'Missed' : 'Taken', kind: l['status'] == 'missed' ? TagKind.danger : TagKind.active),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

/* ---------------------------------------------------------- notifications */

class PatientAlertsPage extends StatelessWidget {
  const PatientAlertsPage({super.key});

  static const _icons = {'reminder': Icons.schedule, 'regimen': Icons.description_outlined, 'message': Icons.chat_bubble_outline, 'alert': Icons.error_outline};

  @override
  Widget build(BuildContext context) {
    final api = context.read<Api>();
    final session = context.read<Session>();
    return Loader<List<Json>>(
      load: () async => _list((await api.get('/notifications', withNow: true))['notifications']),
      loadingHeader: const PageHeader(title: 'Notifications'),
      builder: (context, items, reload) {
        final unread = items.where((n) => n['read'] != true).length;
        return PageScaffold(
          maxWidth: 880,
          onRefresh: () async {
            await reload();
            if (context.mounted) context.read<Badges>().refresh('patient');
          },
          header: PageHeader(
            title: 'Notifications',
            sub: unread > 0 ? '$unread unread' : 'All caught up',
            actions: [
              if (unread > 0)
                LinkBtn('Mark all read', onTap: () async {
                  try {
                    await api.post('/notifications/read-all');
                    await reload();
                    if (context.mounted) context.read<Badges>().refresh('patient');
                  } on ApiException catch (e) {
                    if (context.mounted) toast(context, e.message, error: true);
                  }
                }),
            ],
          ),
          children: [
            if (items.isEmpty) const EmptyCard('You have no notifications.'),
            for (final n in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RowItem(
                  leading: TypeIcon(_icons[n['kind']] ?? Icons.notifications_none, kind: n['kind'] == 'alert' ? IconKind.danger : IconKind.primary),
                  title: '${n['title']}',
                  subs: [if ('${n['body']}'.isNotEmpty) '${n['body']}', relTime('${n['createdAt']}')],
                  subLines: 2,
                  trailing: n['read'] == true ? null : Container(width: 10, height: 10, decoration: const BoxDecoration(color: TP.primary, shape: BoxShape.circle)),
                  onTap: () async {
                    final router = GoRouter.of(context);
                    try {
                      if (n['read'] != true) await api.post('/notifications/${n['id']}/read');
                    } on ApiException {
                      // Reading is best-effort.
                    }
                    if (n['kind'] == 'message') {
                      router.go('/patient/profile/messages');
                    } else {
                      await reload();
                    }
                    if (context.mounted) context.read<Badges>().refresh(session.role);
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

/* ---------------------------------------------------------------- profile */

class _ProfileData {
  _ProfileData(this.regimens, this.history, this.adherence);
  final List<Json> regimens;
  final List<Json> history;
  final Json adherence;
}

class PatientProfilePage extends StatelessWidget {
  const PatientProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<Api>();
    final session = context.watch<Session>();
    final u = session.user ?? {};
    return Loader<_ProfileData>(
      load: () async {
        final r = await Future.wait<Json>([api.get('/patient/regimens'), api.get('/patient/history'), api.get('/patient/adherence', withNow: true)]);
        await session.refreshUser();
        return _ProfileData(_list(r[0]['regimens']), _list(r[1]['history']), r[2]);
      },
      loadingHeader: const PageHeader(title: 'Profile'),
      builder: (context, data, reload) {
        final active = data.regimens.where((r) => r['active'] == true).length;
        final rate = data.adherence['rate'];
        final clinician = u['clinician'] as Map?;
        Widget focus(String route, IconData icon, String title, String sub) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RowItem(leading: TypeIcon(icon), title: title, subs: [sub], trailing: const Icon(Icons.chevron_right, color: TP.muted), onTap: () => context.go(route)),
            );
        final heroCard = TpCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
          child: SizedBox(
            width: double.infinity,
            child: Column(children: [
              Avatar('${u['initials'] ?? ''}', size: 72),
              const SizedBox(height: 12),
              Text('${u['name'] ?? ''}', style: tpText(20, w: FontWeight.w700, ls: -0.4)),
              const SizedBox(height: 3),
              Text('Patient \u00b7 ${u['plan'] ?? 'Care plan'}', style: rowSub),
              const SizedBox(height: 12),
              Tag('Member since ${prettyDate('${u['memberSince'] ?? ''}'.split('T').first)}'),
            ]),
          ),
        );
        final infoCard = TpCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: KvList([
            ('Name', '${u['name'] ?? ''}'),
            ('Contact', [u['email'], u['phone']].where((s) => s != null && '$s'.isNotEmpty).join('\n')),
            ('Date of birth', '${u['dob'] ?? ''}'.isEmpty ? '\u2014' : prettyDate('${u['dob']}')),
            ('Care team', clinician == null ? 'Not linked yet' : '${clinician['name']}'),
          ]),
        );
        final focusRows = <Widget>[
          focus('/patient/regimen', Icons.medication_outlined, 'My Regimens', plural(active, 'active item')),
          focus('/patient/profile/history', Icons.description_outlined, 'Medical History', plural(data.history.length, 'record')),
          focus('/patient/profile/adherence', Icons.trending_up, 'Adherence Stats', rate == null ? 'No doses logged yet' : '$rate% over 30 days'),
          if (clinician != null) focus('/patient/profile/messages', Icons.chat_bubble_outline, 'Message ${clinician['name']}', 'Ask a question about your regimen'),
        ];
        final editBtn = TpButton('Edit Contact Info', icon: Icons.edit_outlined, block: true, onPressed: () => context.go('/patient/profile/contact'));
        final signOutRow = RowItem(
          leading: const TypeIcon(Icons.logout, kind: IconKind.neutral),
          title: 'Sign out',
          subs: const ['Therapy Pal v1.0'],
          onTap: () async {
            final badges = context.read<Badges>();
            await context.read<Session>().logout();
            badges.reset();
          },
        );

        if (context.isCompact) {
          return PageScaffold(
            onRefresh: reload,
            header: const PageHeader(title: 'Profile'),
            children: [
              heroCard,
              const SectionHead('Patient Profile'),
              infoCard,
              const SectionHead('Focus'),
              ...focusRows,
              const SizedBox(height: 10),
              editBtn,
              const SectionHead('Account'),
              signOutRow,
            ],
          );
        }
        return PageScaffold(
          onRefresh: reload,
          maxWidth: 1100,
          header: const PageHeader(title: 'Profile', sub: 'Your details and shortcuts'),
          children: [
            MainAside(
              main: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [heroCard, const SectionHead('Patient Profile'), infoCard]),
              aside: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionHead('Focus', top: 0),
                ...focusRows,
                const SizedBox(height: 10),
                editBtn,
                const SectionHead('Account'),
                signOutRow,
              ]),
            ),
          ],
        );
      },
    );
  }
}

/* ---------------------------------------------------------------- history */

class PatientHistoryPage extends StatelessWidget {
  const PatientHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<Api>();
    return Loader<List<Json>>(
      load: () async => _list((await api.get('/patient/history'))['history']),
      loadingHeader: const PageHeader(title: 'Medical History', backTo: '/patient/profile'),
      builder: (context, items, reload) => PageScaffold(
        onRefresh: reload,
        header: PageHeader(title: 'Medical History', sub: plural(items.length, 'record'), backTo: '/patient/profile'),
        children: [
          if (items.isEmpty) const EmptyCard('No records yet.'),
          GridList(minTileWidth: 380, children: [
            for (final h in items)
              TpCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(prettyDate('${h['date']}').toUpperCase(), style: eyebrow),
                    const SizedBox(height: 6),
                    Text('${h['title']}', style: rowTitle),
                    if ('${h['detail']}'.isNotEmpty) ...[const SizedBox(height: 6), Text('${h['detail']}', style: tpText(12.5, color: TP.muted, h: 1.5))],
                    if ('${h['place']}'.isNotEmpty) ...[const SizedBox(height: 6), Text('${h['place']}', style: rowSub)],
                  ]),
                ),
              ),
          ]),
        ],
      ),
    );
  }
}

/* -------------------------------------------------------------- adherence */

class PatientAdherencePage extends StatelessWidget {
  const PatientAdherencePage({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<Api>();
    return Loader<Json>(
      load: () => api.get('/patient/adherence', withNow: true),
      loadingHeader: const PageHeader(title: 'Adherence Stats', backTo: '/patient/profile'),
      builder: (context, a, reload) {
        final rate = (a['rate'] as num?)?.toInt();
        final weekly = (a['weekly'] as List).map((e) => (e as num?)?.toInt()).toList();
        final slips = _list(a['slips']);
        final totalMissed = (a['missed'] as num).toInt();
        final ringCard = TpCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: SizedBox(
            width: double.infinity,
            child: Column(children: [
              Ring(pct: rate, caption: 'adherence'),
              const SizedBox(height: 14),
              Text(
                rate == null ? 'Log your first dose to see your adherence.' : 'You logged ${a['taken']} of ${a['scheduled']} scheduled doses in the last 30 days.',
                textAlign: TextAlign.center,
                style: tpText(13.5, color: TP.muted, h: 1.55),
              ),
            ]),
          ),
        );
        final trendCard = TpCard(
          padding: const EdgeInsets.all(16),
          child: BarChart(values: weekly, labels: [for (var i = 0; i < weekly.length; i++) 'W${i + 1}']),
        );
        final stats = StatStrip([
          StatTile('${a['streak']}', 'Day streak'),
          StatTile('$totalMissed', 'Doses missed'),
          StatTile('${a['dosesToday']}', 'Doses today'),
        ]);
        final slipsCard = TpCard(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            for (var i = 0; i < slips.length; i++) ...[
              if (i > 0) const SizedBox(height: 14),
              MeterRow(label: '${slips[i]['label']}', count: (slips[i]['missed'] as num).toInt(), total: totalMissed),
            ],
          ]),
        );
        final header = const PageHeader(title: 'Adherence Stats', sub: 'Last 30 days', backTo: '/patient/profile');

        if (context.isCompact) {
          return PageScaffold(
            onRefresh: reload,
            header: header,
            children: [
              ringCard,
              SectionHead('Weekly trend', trailing: Text('% on time', style: mutedSm)),
              trendCard,
              const SizedBox(height: 16),
              stats,
              const SectionHead('Where doses slip'),
              slipsCard,
            ],
          );
        }
        return PageScaffold(
          onRefresh: reload,
          maxWidth: 1100,
          header: header,
          children: [
            stats,
            MainAside(
              main: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SectionHead('Weekly trend', trailing: Text('% on time', style: mutedSm)),
                trendCard,
                const SectionHead('Where doses slip'),
                slipsCard,
              ]),
              aside: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const SectionHead('30-day adherence'), ringCard]),
            ),
          ],
        );
      },
    );
  }
}

/* ---------------------------------------------------------------- contact */

class PatientContactPage extends StatefulWidget {
  const PatientContactPage({super.key});

  @override
  State<PatientContactPage> createState() => _PatientContactPageState();
}

class _PatientContactPageState extends State<PatientContactPage> {
  late final TextEditingController _name, _email, _phone;
  String? _nameErr, _emailErr, _formErr;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final u = context.read<Session>().user ?? {};
    _name = TextEditingController(text: '${u['name'] ?? ''}');
    _email = TextEditingController(text: '${u['email'] ?? ''}');
    _phone = TextEditingController(text: '${u['phone'] ?? ''}');
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nameBad = _name.text.trim().length < 2;
    final emailBad = !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());
    setState(() {
      _nameErr = nameBad ? 'Enter your full name.' : null;
      _emailErr = emailBad ? 'Enter a valid email address.' : null;
      _formErr = null;
    });
    if (nameBad || emailBad) return;
    final api = context.read<Api>();
    final session = context.read<Session>();
    final router = GoRouter.of(context);
    setState(() => _busy = true);
    try {
      final res = await api.patch('/auth/me', {'name': _name.text.trim(), 'email': _email.text.trim(), 'phone': _phone.text.trim()});
      session.setUser(Map<String, dynamic>.from(res['user'] as Map));
      if (!mounted) return;
      toast(context, 'Contact info saved');
      router.go('/patient/profile');
    } on ApiException catch (e) {
      if (mounted) setState(() => _formErr = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      maxWidth: 560,
      header: const PageHeader(title: 'Edit Contact Info', backTo: '/patient/profile'),
      children: [
        TpField(label: 'Full name', controller: _name, error: _nameErr),
        const SizedBox(height: 16),
        TpField(label: 'Email', controller: _email, keyboard: TextInputType.emailAddress, error: _emailErr),
        const SizedBox(height: 16),
        TpField(label: 'Phone', controller: _phone, keyboard: TextInputType.phone),
        const SizedBox(height: 16),
        Text('Your care team uses these details to reach you about your regimen.', style: tpText(12, color: TP.muted)),
        if (_formErr != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: TP.dangerBg, borderRadius: BorderRadius.circular(TP.radiusSm)),
            child: Text(_formErr!, style: tpText(13.5, w: FontWeight.w600, color: TP.danger)),
          ),
        ],
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: TpButton('Cancel', kind: BtnKind.ghost, onPressed: () => context.go('/patient/profile'))),
          const SizedBox(width: 8),
          Expanded(child: TpButton('Save changes', onPressed: _save, loading: _busy)),
        ]),
      ],
    );
  }
}

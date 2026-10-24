import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/api.dart';
import '../../core/responsive.dart';
import '../../core/tokens.dart';
import '../../state/session.dart';
import '../../widgets/page.dart';
import '../../widgets/ui.dart';

class ClinicianProfilePage extends StatelessWidget {
  const ClinicianProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final u = session.user ?? {};
    final clinics = (u['clinics'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    Widget link(String route, IconData icon, String title, String sub) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: RowItem(leading: TypeIcon(icon), title: title, subs: [sub], trailing: const Icon(Icons.chevron_right, color: TP.muted), onTap: () => context.go(route)),
        );

    final hero = TpCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      child: SizedBox(
        width: double.infinity,
        child: Column(children: [
          Avatar('${u['initials'] ?? ''}', size: 72),
          const SizedBox(height: 12),
          Text('${u['name'] ?? ''}', style: tpText(20, w: FontWeight.w700, ls: -0.4)),
          const SizedBox(height: 3),
          Text('${u['specialization'] ?? ''}', style: rowSub),
          const SizedBox(height: 12),
          Tag('NPI ${u['npi'] ?? ''}'),
        ]),
      ),
    );
    final info = TpCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: KvList([
        ('NPI Number', '${u['npi'] ?? ''}'),
        ('Specialization', '${u['specialization'] ?? ''}'),
        ('Licence', '${u['license'] ?? ''}'.isEmpty ? '\u2014' : '${u['license']}'),
        ('Contact', '${u['email'] ?? ''}'),
      ]),
    );
    final settings = <Widget>[
      link('/clinician/profile/clinic', Icons.apartment, 'Clinic Info', '${clinics.length} affiliated ${clinics.length == 1 ? 'clinic' : 'clinics'}'),
      link('/clinician/profile/prefs', Icons.settings_outlined, 'Notification Preferences', 'Reminders and alerts'),
    ];
    final clinicRows = <Widget>[
      if (clinics.isEmpty) const EmptyCard('No clinics added yet.'),
      for (final c in clinics)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: RowItem(
            leading: const TypeIcon(Icons.apartment),
            title: '${c['name']}',
            subs: ['${c['role']} \u00b7 ${c['patients']} patients'],
            trailing: const Tag('Active'),
          ),
        ),
    ];
    final signOut = TpButton('Sign out', icon: Icons.logout, kind: BtnKind.ghost, block: true, onPressed: () async {
      final badges = context.read<Badges>();
      await context.read<Session>().logout();
      badges.reset();
    });

    if (context.isCompact) {
      return PageScaffold(
        onRefresh: session.refreshUser,
        header: const PageHeader(title: 'Profile'),
        children: [
          hero,
          const SectionHead('Clinician Profile'),
          info,
          const SectionHead('App Settings'),
          ...settings,
          const SectionHead('My Clinics'),
          ...clinicRows,
          const SizedBox(height: 10),
          signOut,
        ],
      );
    }
    return PageScaffold(
      onRefresh: session.refreshUser,
      maxWidth: 1100,
      header: const PageHeader(title: 'Profile', sub: 'Your details and practice settings'),
      children: [
        MainAside(
          main: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [hero, const SectionHead('Clinician Profile'), info]),
          aside: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SectionHead('App Settings', top: 0),
            ...settings,
            const SectionHead('My Clinics'),
            ...clinicRows,
            const SizedBox(height: 10),
            signOut,
          ]),
        ),
      ],
    );
  }
}

class ClinicianClinicPage extends StatelessWidget {
  const ClinicianClinicPage({super.key});

  @override
  Widget build(BuildContext context) {
    final u = context.watch<Session>().user ?? {};
    final clinics = (u['clinics'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return PageScaffold(
      maxWidth: 720,
      header: const PageHeader(title: 'Clinic Info', backTo: '/clinician/profile'),
      children: [
        if (clinics.isEmpty) const EmptyCard('No clinics added yet.'),
        for (final c in clinics)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TpCard(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${c['name']}', style: rowTitle),
                  const SizedBox(height: 6),
                  Text('${c['role']}', style: rowSub),
                  const SizedBox(height: 6),
                  Text('${c['address']}', style: rowSub),
                  const SizedBox(height: 10),
                  Tag('${c['patients']} patients under your care', kind: TagKind.active),
                ]),
              ),
            ),
          ),
      ],
    );
  }
}

class ClinicianPrefsPage extends StatefulWidget {
  const ClinicianPrefsPage({super.key});

  @override
  State<ClinicianPrefsPage> createState() => _ClinicianPrefsPageState();
}

class _ClinicianPrefsPageState extends State<ClinicianPrefsPage> {
  static const _rows = [
    ('doseReminders', 'Dose reminders', 'Reminders for your own scheduled items'),
    ('missedDose', 'Missed-dose alerts', 'Know when a patient misses a dose'),
    ('clinicianMessages', 'New messages', 'Alerts when a patient writes to you'),
    ('weeklySummary', 'Weekly summary', 'A digest of panel adherence each week'),
  ];
  bool _busy = false;

  Future<void> _set(String key, bool value) async {
    final api = context.read<Api>();
    final session = context.read<Session>();
    final before = Map<String, dynamic>.from(session.user ?? {});
    final prefs = Map<String, dynamic>.from((before['prefs'] as Map?) ?? {})..[key] = value;
    session.setUser({...before, 'prefs': prefs}); // optimistic
    setState(() => _busy = true);
    try {
      final res = await api.patch('/auth/me/prefs', {key: value});
      session.setUser(Map<String, dynamic>.from(res['user'] as Map));
    } on ApiException catch (e) {
      session.setUser(before);
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = (context.watch<Session>().user?['prefs'] as Map?) ?? {};
    return PageScaffold(
      maxWidth: 720,
      header: const PageHeader(title: 'Notification Preferences', backTo: '/clinician/profile'),
      children: [
        for (final (key, title, sub) in _rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TpCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: rowTitle),
                    const SizedBox(height: 2),
                    Text(sub, style: rowSub),
                  ]),
                ),
                Switch(
                  value: prefs[key] != false,
                  activeTrackColor: TP.primary,
                  onChanged: _busy ? null : (v) => _set(key, v),
                ),
              ]),
            ),
          ),
      ],
    );
  }
}

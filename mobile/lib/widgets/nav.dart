import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/format.dart';
import '../core/responsive.dart';
import '../core/tokens.dart';
import '../state/session.dart';
import 'ui.dart';

class NavItem {
  const NavItem(this.label, this.icon);
  final String label;
  final IconData icon;
}

const patientNav = [
  NavItem('Home', Icons.home_outlined),
  NavItem('Regimen', Icons.medication_outlined),
  NavItem('Logs', Icons.history),
  NavItem('Alerts', Icons.notifications_none),
  NavItem('Profile', Icons.person_outline),
];

const clinicianNav = [
  NavItem('Dashboard', Icons.dashboard_outlined),
  NavItem('Patients', Icons.groups_outlined),
  NavItem('Messages', Icons.chat_bubble_outline),
  NavItem('Analytics', Icons.trending_up),
  NavItem('Profile', Icons.person_outline),
];

class TpNavBar extends StatelessWidget {
  const TpNavBar({super.key, required this.items, required this.index, required this.onTap, this.badges = const {}});
  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onTap;
  final Map<int, int> badges;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: TP.surface, border: Border(top: BorderSide(color: TP.line))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
          child: Row(children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == index,
                  label: items[i].label,
                  child: InkResponse(
                    onTap: () => onTap(i),
                    radius: 36,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 52),
                      child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                        Stack(clipBehavior: Clip.none, children: [
                          Icon(items[i].icon, size: 24, color: i == index ? TP.primary : TP.muted, weight: i == index ? 700 : 400),
                          if ((badges[i] ?? 0) > 0)
                            Positioned(
                              top: -5,
                              right: -9,
                              child: Container(
                                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: TP.danger, borderRadius: BorderRadius.circular(99)),
                                child: Text('${badges[i]}', style: tpText(10, w: FontWeight.w700, color: Colors.white)),
                              ),
                            ),
                        ]),
                        const SizedBox(height: 3),
                        Text(items[i].label, style: tpText(10.5, w: FontWeight.w700, color: i == index ? TP.primary : TP.muted)),
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Shell for both roles. Phone: bottom bar. Tablet: 72px icon rail + top bar. Laptop: 260px sidebar + top bar.
class RoleShell extends StatefulWidget {
  const RoleShell({super.key, required this.shell, required this.role});
  final StatefulNavigationShell shell;
  final String role;

  @override
  State<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends State<RoleShell> {
  bool get _patient => widget.role == 'patient';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<Badges>().refresh(widget.role);
    });
  }

  void _go(int i) {
    widget.shell.goBranch(i, initialLocation: i == widget.shell.currentIndex);
    context.read<Badges>().refresh(widget.role);
  }

  @override
  Widget build(BuildContext context) {
    final badges = context.watch<Badges>();
    final items = _patient ? patientNav : clinicianNav;
    final counts = _patient ? {3: badges.alerts} : {2: badges.messages};
    final size = context.screenSize;

    if (size == ScreenSize.compact) {
      return Scaffold(
        backgroundColor: TP.ground,
        body: widget.shell,
        bottomNavigationBar: TpNavBar(items: items, index: widget.shell.currentIndex, badges: counts, onTap: _go),
      );
    }

    return Scaffold(
      backgroundColor: TP.ground,
      body: Row(children: [
        size == ScreenSize.expanded
            ? _Sidebar(items: items, index: widget.shell.currentIndex, badges: counts, onTap: _go, role: widget.role)
            : _Rail(items: items, index: widget.shell.currentIndex, badges: counts, onTap: _go),
        Expanded(
          child: Column(children: [
            _TopBar(role: widget.role, badge: _patient ? badges.alerts : badges.messages),
            Expanded(child: widget.shell),
          ]),
        ),
      ]),
    );
  }
}

Future<void> _signOut(BuildContext context) async {
  final badges = context.read<Badges>();
  await context.read<Session>().logout();
  badges.reset();
}

class _CountPill extends StatelessWidget {
  const _CountPill(this.n, {this.onDark = false});
  final int n;
  final bool onDark;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: onDark ? Colors.white : TP.danger, borderRadius: BorderRadius.circular(99)),
        child: Text('$n', style: tpText(11, w: FontWeight.w700, color: onDark ? TP.primary700 : Colors.white)),
      );
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.items, required this.index, required this.badges, required this.onTap, required this.role});
  final List<NavItem> items;
  final int index;
  final Map<int, int> badges;
  final ValueChanged<int> onTap;
  final String role;

  @override
  Widget build(BuildContext context) {
    final u = context.watch<Session>().user ?? {};
    return Container(
      width: 260,
      decoration: const BoxDecoration(color: Color(0xB3FFFFFF), border: Border(right: BorderSide(color: TP.line))),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const LogoMark(size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Therapy Pal', style: tpText(18, w: FontWeight.w700, ls: -0.3)),
              Text(role == 'patient' ? 'PATIENT PORTAL' : 'CLINICIAN SUITE', style: tpText(10.5, w: FontWeight.w700, color: TP.muted, ls: 0.8)),
            ]),
          ),
        ]),
        const SizedBox(height: 28),
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Semantics(
              button: true,
              selected: i == index,
              label: items[i].label,
              child: Material(
                color: i == index ? TP.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(TP.radiusSm),
                child: InkWell(
                  borderRadius: BorderRadius.circular(TP.radiusSm),
                  hoverColor: i == index ? Colors.transparent : TP.primary050,
                  onTap: () => onTap(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(children: [
                      Icon(items[i].icon, size: 20, color: i == index ? Colors.white : TP.muted),
                      const SizedBox(width: 12),
                      Expanded(child: Text(items[i].label, style: tpText(14.5, w: FontWeight.w600, color: i == index ? Colors.white : TP.ink2))),
                      if ((badges[i] ?? 0) > 0) _CountPill(badges[i]!, onDark: i == index),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: TP.primary050, borderRadius: BorderRadius.circular(TP.radius)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Avatar('${u['initials'] ?? ''}', size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${u['name'] ?? ''}', style: tpText(13.5, w: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(role == 'patient' ? 'Patient' : '${u['specialization'] ?? 'Clinician'}', style: tpText(12, color: TP.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            TpButton('Sign out', icon: Icons.logout, kind: BtnKind.ghost, small: true, block: true, onPressed: () => _signOut(context)),
          ]),
        ),
      ]),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.items, required this.index, required this.badges, required this.onTap});
  final List<NavItem> items;
  final int index;
  final Map<int, int> badges;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final u = context.watch<Session>().user ?? {};
    return Container(
      width: 72,
      decoration: const BoxDecoration(color: Color(0xB3FFFFFF), border: Border(right: BorderSide(color: TP.line))),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(children: [
        const LogoMark(size: 40),
        const SizedBox(height: 24),
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Tooltip(
              message: items[i].label,
              child: Semantics(
                button: true,
                selected: i == index,
                label: items[i].label,
                child: Stack(clipBehavior: Clip.none, children: [
                  Material(
                    color: i == index ? TP.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(TP.radiusSm),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(TP.radiusSm),
                      hoverColor: i == index ? Colors.transparent : TP.primary050,
                      onTap: () => onTap(i),
                      child: SizedBox(width: 48, height: 48, child: Icon(items[i].icon, size: 22, color: i == index ? Colors.white : TP.muted)),
                    ),
                  ),
                  if ((badges[i] ?? 0) > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: TP.danger, borderRadius: BorderRadius.circular(99), border: Border.all(color: TP.surface, width: 2)),
                        child: Text('${badges[i]}', style: tpText(10, w: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                ]),
              ),
            ),
          ),
        const Spacer(),
        Avatar('${u['initials'] ?? ''}', size: 36),
        const SizedBox(height: 8),
        Tooltip(message: 'Sign out', child: IconBox(icon: Icons.logout, bare: true, label: 'Sign out', onTap: () => _signOut(context))),
      ]),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.role, required this.badge});
  final String role;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final u = context.watch<Session>().user ?? {};
    final patient = role == 'patient';
    final gutter = pageGutter(context.screenSize);
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: gutter),
      decoration: const BoxDecoration(color: Color(0xEBFFFFFF), border: Border(bottom: BorderSide(color: TP.line))),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(color: TP.primary050, borderRadius: BorderRadius.circular(99)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.calendar_today_outlined, size: 15, color: TP.primary700),
            const SizedBox(width: 8),
            Text(longToday(), style: tpText(13, w: FontWeight.w600, color: TP.primary700)),
          ]),
        ),
        const Spacer(),
        IconBox(
          icon: patient ? Icons.notifications_none : Icons.chat_bubble_outline,
          badge: badge,
          label: patient ? 'Notifications' : 'Messages',
          onTap: () => context.go(patient ? '/patient/alerts' : '/clinician/messages'),
        ),
        const SizedBox(width: 12),
        InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: () => context.go(patient ? '/patient/profile' : '/clinician/profile'),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Avatar('${u['initials'] ?? ''}', size: 34),
              if (context.screenSize == ScreenSize.expanded) ...[
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text('${u['name'] ?? ''}', style: tpText(13.5, w: FontWeight.w700)),
                  Text(patient ? 'Patient' : '${u['specialization'] ?? 'Clinician'}', style: tpText(11.5, color: TP.muted)),
                ]),
                const SizedBox(width: 6),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/auth.dart';
import 'screens/clinician/pages.dart';
import 'screens/clinician/profile.dart';
import 'screens/patient/home.dart';
import 'screens/patient/pages.dart';
import 'screens/thread.dart';
import 'state/session.dart';
import 'widgets/nav.dart';

GoRouter buildRouter(Session session) {
  String? redirect(BuildContext context, GoRouterState state) {
    final loc = state.matchedLocation;
    final authPages = loc == '/login' || loc == '/register';
    switch (session.status) {
      case AuthStatus.booting:
        return loc == '/splash' ? null : '/splash';
      case AuthStatus.signedOut:
        return authPages ? null : '/login';
      case AuthStatus.signedIn:
        final home = session.isClinician ? '/clinician/dashboard' : '/patient/home';
        if (loc == '/' || loc == '/splash' || authPages) return home;
        if (loc.startsWith('/patient') && session.role != 'patient') return home;
        if (loc.startsWith('/clinician') && session.role != 'clinician') return home;
        return null;
    }
  }

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: session,
    redirect: redirect,
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),

      // Patient experience
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => RoleShell(shell: shell, role: 'patient'),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/patient/home', builder: (_, _) => const PatientHomePage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/patient/regimen', builder: (_, _) => const PatientRegimenPage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/patient/logs', builder: (_, _) => const PatientLogsPage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/patient/alerts', builder: (_, _) => const PatientAlertsPage())]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/patient/profile',
              builder: (_, _) => const PatientProfilePage(),
              routes: [
                GoRoute(path: 'history', builder: (_, _) => const PatientHistoryPage()),
                GoRoute(path: 'adherence', builder: (_, _) => const PatientAdherencePage()),
                GoRoute(path: 'contact', builder: (_, _) => const PatientContactPage()),
                GoRoute(
                  path: 'messages',
                  builder: (context, _) => ThreadPage(patientId: session.id, backTo: '/patient/profile', subtitle: 'Your care team'),
                ),
              ],
            ),
          ]),
        ],
      ),

      // Clinician experience
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => RoleShell(shell: shell, role: 'clinician'),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/clinician/dashboard', builder: (_, _) => const ClinicianDashboardPage())]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/clinician/patients',
              builder: (_, _) => const ClinicianPatientsPage(),
              routes: [GoRoute(path: ':id', builder: (_, s) => ClinicianPatientPage(patientId: s.pathParameters['id']!))],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/clinician/messages',
              builder: (_, _) => const ClinicianMessagesPage(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, s) => ClinicianMessagesPage(selectedId: s.pathParameters['id']),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [GoRoute(path: '/clinician/analytics', builder: (_, _) => const ClinicianAnalyticsPage())]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/clinician/profile',
              builder: (_, _) => const ClinicianProfilePage(),
              routes: [
                GoRoute(path: 'clinic', builder: (_, _) => const ClinicianClinicPage()),
                GoRoute(path: 'prefs', builder: (_, _) => const ClinicianPrefsPage()),
              ],
            ),
          ]),
        ],
      ),
    ],
  );
}

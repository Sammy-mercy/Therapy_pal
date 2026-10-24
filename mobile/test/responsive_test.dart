import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:therapy_pal/core/api.dart';
import 'package:therapy_pal/core/format.dart';
import 'package:therapy_pal/router.dart';
import 'package:therapy_pal/screens/thread.dart';
import 'package:therapy_pal/state/session.dart';
import 'package:therapy_pal/widgets/nav.dart';
import 'package:therapy_pal/widgets/ui.dart';

http.Response _json(Object body) => http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});

Map<String, dynamic> _dose(String slot, String status, {String? logged}) => {
      'regimenId': 'r1', 'name': 'Ibuprofen', 'strength': '200 mg', 'type': 'medication',
      'label': 'Ibuprofen 200 mg', 'day': nowDay(), 'slot': slot, 'status': status, 'loggedTime': logged,
    };

Map<String, dynamic> _regimen(String id, String name, String type, {bool active = true}) => {
      'id': id, 'name': name, 'strength': '200 mg', 'type': type, 'active': active, 'schedule': '3 times daily, after meals',
      'times': ['08:00', '13:00', '20:00'], 'started': '2026-09-12', 'prescriber': 'Dr. Sarah Carter', 'note': 'Take with food to avoid stomach upset.',
    };

final _patientUser = {
  'id': 'u1', 'role': 'patient', 'name': 'Alex Rivera', 'initials': 'AR', 'email': 'alex@x.com', 'phone': '(415) 555-0134', 'dob': 'March 14, 1991',
  'memberSince': '2026-09-01T00:00:00Z', 'plan': 'Recovery plan', 'clinician': {'id': 'c1', 'name': 'Dr. Sarah Carter'}, 'prefs': {},
};

final _clinicianUser = {
  'id': 'c1', 'role': 'clinician', 'name': 'Dr. Sarah Carter', 'initials': 'SC', 'email': 's.carter@x.org', 'phone': '', 'dob': '',
  'memberSince': '2025-09-01T00:00:00Z', 'npi': '1740293847', 'specialization': 'Internal Medicine', 'license': 'CA-1', 'prefs': {},
  'clinics': [
    {'id': 'k1', 'name': 'Downtown Clinic', 'role': 'Attending physician', 'address': '420 Market St', 'patients': 4},
    {'id': 'k2', 'name': 'Westside Clinic', 'role': 'Consulting physician', 'address': '1180 West Ave', 'patients': 2},
  ],
};

Map<String, dynamic> _patientRow(String id, String name, int rate) => {
      'id': id, 'name': name, 'initials': name.split(' ').map((s) => s[0]).take(2).join(), 'note': 'Post-operative ankle recovery', 'age': 35,
      'since': '2026-08-01T00:00:00Z', 'rate': rate, 'missed': 3, 'regimen': 'Ibuprofen 200 mg \u00b7 Ankle Exercises 15 min set \u00b7 Amoxicillin 500 mg',
      'lastLog': {'day': nowDay(), 'time': '08:05'}, 'unreadMessages': 1,
    };

final _threads = {
  'threads': [
    {'patientId': 'p1', 'name': 'Alex Rivera', 'initials': 'AR', 'unread': 2, 'last': {'id': 'm1', 'from': 'them', 'text': 'The ankle exercises are getting easier with the band.', 'createdAt': DateTime.now().toUtc().toIso8601String()}},
    {'patientId': 'p2', 'name': 'Jordan Blake', 'initials': 'JB', 'unread': 0, 'last': {'id': 'm2', 'from': 'me', 'text': 'Keep going, rest if sore.', 'createdAt': DateTime.now().toUtc().toIso8601String()}},
  ],
  'unread': 2,
};

MockClient _server() => MockClient((req) async {
      final p = req.url.path.replaceFirst('/api', '');
      if (p == '/auth/me') return _json({'user': _patientUser});
      // patient
      if (p == '/patient/regimens') return _json({'regimens': [_regimen('r1', 'Ibuprofen', 'medication'), _regimen('r2', 'Ankle Exercises', 'therapy'), _regimen('r3', 'Vitamin D3', 'medication', active: false)]});
      if (p == '/patient/today') return _json({'day': nowDay(), 'doses': [_dose('08:00', 'taken', logged: '08:05'), _dose('13:00', 'due'), _dose('20:00', 'upcoming')], 'taken': 1, 'total': 3, 'next': _dose('13:00', 'due')});
      if (p == '/patient/adherence') {
        return _json({
          'rate': 88, 'taken': 80, 'missed': 10, 'scheduled': 90, 'streak': 4, 'dosesToday': 3, 'todayTaken': 1, 'weekly': [null, null, 100, 96, 91, 44],
          'slips': [
            {'key': 'morning', 'label': 'Morning 6\u201311 AM', 'missed': 2}, {'key': 'midday', 'label': 'Midday 11 AM\u20134 PM', 'missed': 1},
            {'key': 'evening', 'label': 'Evening 4\u20139 PM', 'missed': 6}, {'key': 'night', 'label': 'Night 9 PM\u20136 AM', 'missed': 1},
          ],
        });
      }
      if (p == '/notifications') {
        return _json({
          'notifications': [
            {'id': 'n1', 'kind': 'reminder', 'title': 'Take Ibuprofen in 30 min', 'body': 'Scheduled dose at 13:00.', 'read': false, 'createdAt': DateTime.now().toUtc().toIso8601String()},
            {'id': 'n2', 'kind': 'message', 'title': 'Message from Dr. Sarah Carter', 'body': 'Keep it within an hour.', 'read': true, 'createdAt': DateTime.now().toUtc().toIso8601String()},
          ],
          'unread': 3,
        });
      }
      if (p == '/patient/logs') return _json({'logs': [{'day': nowDay(), 'label': 'Ibuprofen 200 mg', 'time': '08:05', 'status': 'taken'}, {'day': nowDay(), 'label': 'Amoxicillin 500 mg', 'time': '08:00', 'status': 'missed'}]});
      if (p == '/patient/history') return _json({'history': [{'id': 'h1', 'date': '2026-09-24', 'title': 'Ankle arthroscopy - follow-up', 'detail': 'Range of motion improving.', 'place': 'Downtown Clinic'}, {'id': 'h2', 'date': '2026-09-12', 'title': 'Ankle arthroscopy', 'detail': 'Outpatient procedure.', 'place': 'Westside Surgical Center'}]});
      // clinician
      if (p == '/clinician/patients') {
        return _json({'patients': [_patientRow('p1', 'Alex Rivera', 92), _patientRow('p2', 'Jordan Blake', 55), _patientRow('p3', 'Maya Chen', 88)], 'summary': {'total': 3, 'avgAdherence': 78, 'needsAttention': 1}});
      }
      if (p.startsWith('/clinician/patients/')) {
        return _json({'patient': {..._patientRow('p1', 'Alex Rivera', 92), 'email': 'a@x.com', 'phone': '1', 'dob': 'March 14, 1991'}, 'regimens': [_regimen('r1', 'Ibuprofen', 'medication')], 'history': []});
      }
      if (p == '/clinician/analytics') {
        return _json({
          'avgAdherence': 78, 'onTrack': 2, 'patients': 3, 'missed': 24,
          'byPatient': [{'id': 'p1', 'name': 'Alex Rivera', 'rate': 92}, {'id': 'p2', 'name': 'Jordan Blake', 'rate': 55}, {'id': 'p3', 'name': 'Maya Chen', 'rate': 88}],
          'trend': [86, 89, 88, 92, 90, 91, 84, 78],
          'slips': [{'key': 'morning', 'label': 'Morning 6\u201311 AM', 'missed': 4}, {'key': 'midday', 'label': 'Midday 11 AM\u20134 PM', 'missed': 5}, {'key': 'evening', 'label': 'Evening 4\u20139 PM', 'missed': 13}, {'key': 'night', 'label': 'Night 9 PM\u20136 AM', 'missed': 2}],
        });
      }
      if (p == '/messages/threads') return _json(_threads);
      if (p.startsWith('/messages/threads/')) {
        return _json({
          'with': {'id': 'p1', 'name': 'Alex Rivera', 'initials': 'AR'},
          'messages': [
            {'id': 'a', 'from': 'them', 'text': 'Is it okay if I take the ibuprofen a bit late on workdays?', 'createdAt': DateTime.now().toUtc().toIso8601String()},
            {'id': 'b', 'from': 'me', 'text': 'Yes, within about an hour and always with food.', 'createdAt': DateTime.now().toUtc().toIso8601String()},
          ],
        });
      }
      return http.Response('{"error":{"message":"not mocked $p"}}', 404);
    });

const _sizes = <(String, Size)>[
  ('phone 390x844', Size(390, 844)),
  ('small tablet 600x960', Size(600, 960)),
  ('tablet portrait 820x1180', Size(820, 1180)),
  ('tablet landscape 1024x768', Size(1024, 768)),
  ('laptop 1366x768', Size(1366, 768)),
  ('desktop 1440x900', Size(1440, 900)),
  ('wide 1920x1080', Size(1920, 1080)),
];

Future<GoRouter> _boot(WidgetTester tester, Size size, Map<String, dynamic> user) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final api = Api(base: 'http://test/api', client: _server());
  final session = Session(api)
    ..status = AuthStatus.signedIn
    ..user = user;
  final router = buildRouter(session);
  await tester.pumpWidget(MultiProvider(
    providers: [
      Provider<Api>.value(value: api),
      ChangeNotifierProvider<Session>.value(value: session),
      ChangeNotifierProvider<Badges>.value(value: Badges(api)),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
  return router;
}

Future<void> _visit(WidgetTester tester, GoRouter h, String path, {String? expectText}) async {
  h.go(path);
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
  final err = tester.takeException();
  expect(err, isNull, reason: 'exception on $path');
  if (expectText != null) expect(find.textContaining(expectText), findsWidgets, reason: '"$expectText" missing on $path');
}

void main() {
  setUpAll(() => tpUseDeviceFonts = true);

  for (final (label, size) in _sizes) {
    testWidgets('patient screens render without layout errors at $label', (tester) async {
      final h = await _boot(tester, size, _patientUser);
      expect(tester.takeException(), isNull);
      expect(find.text('Today\u2019s doses'), findsWidgets);

      // Navigation style per tier.
      if (size.width < 768) {
        expect(find.byType(TpNavBar), findsOneWidget);
      } else if (size.width < 1280) {
        expect(find.byType(TpNavBar), findsNothing);
        expect(find.text('PATIENT PORTAL'), findsNothing);
      } else {
        expect(find.text('PATIENT PORTAL'), findsOneWidget);
      }

      await _visit(tester, h, '/patient/regimen', expectText: 'My Regimen');
      await _visit(tester, h, '/patient/logs', expectText: 'Last 14 days');
      await _visit(tester, h, '/patient/alerts', expectText: 'Notifications');
      await _visit(tester, h, '/patient/profile', expectText: 'Patient Profile');
      await _visit(tester, h, '/patient/profile/history', expectText: 'Medical History');
      await _visit(tester, h, '/patient/profile/adherence', expectText: 'Adherence Stats');
      await _visit(tester, h, '/patient/profile/contact', expectText: 'Edit Contact Info');
      await _visit(tester, h, '/patient/profile/messages', expectText: 'Your care team');
      await _visit(tester, h, '/patient/home', expectText: 'doses logged');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('clinician screens render without layout errors at $label', (tester) async {
      final h = await _boot(tester, size, _clinicianUser);
      expect(tester.takeException(), isNull);
      expect(find.text('Patient Overview'), findsWidgets);
      if (size.width >= 1280) expect(find.text('CLINICIAN SUITE'), findsOneWidget);

      await _visit(tester, h, '/clinician/patients', expectText: 'in your panel');
      await _visit(tester, h, '/clinician/patients/p1', expectText: 'Current regimen');
      await _visit(tester, h, '/clinician/messages', expectText: 'conversation');
      await _visit(tester, h, '/clinician/messages/p1', expectText: 'Is it okay if I take the ibuprofen');
      if (size.width >= 768) {
        // Split view keeps the inbox visible next to the open conversation.
        expect(find.text('Jordan Blake'), findsWidgets);
        expect(find.byType(ThreadPage), findsOneWidget);
      }
      await _visit(tester, h, '/clinician/analytics', expectText: 'Adherence by patient');
      await _visit(tester, h, '/clinician/profile', expectText: 'Clinician Profile');
      await _visit(tester, h, '/clinician/profile/clinic', expectText: 'Downtown Clinic');
      await _visit(tester, h, '/clinician/profile/prefs', expectText: 'Notification Preferences');
      await _visit(tester, h, '/clinician/dashboard', expectText: 'Patient Overview');
      await tester.pumpWidget(const SizedBox());
    });
  }
}

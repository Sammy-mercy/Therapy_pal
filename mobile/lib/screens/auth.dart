import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/tokens.dart';
import '../state/session.dart';
import '../widgets/ui.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TP.ground,
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const LogoMark(size: 84),
                  const SizedBox(height: 22),
                  Text('Therapy Pal', style: tpText(30, w: FontWeight.w700, ls: -0.9)),
                  const SizedBox(height: 6),
                  Text('Your treatment regimen, reminders and clinician \u2014 in one calm place.',
                      textAlign: TextAlign.center, style: tpText(14.5, color: TP.muted, h: 1.5)),
                  const SizedBox(height: 28),
                  const SizedBox(width: 120, child: _SplashBar()),
                ]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Text('Care that keeps up with you', style: tpText(12.5, w: FontWeight.w600, color: TP.muted)),
          ),
        ]),
      ),
    );
  }
}

class _SplashBar extends StatelessWidget {
  const _SplashBar();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1300),
      curve: TP.ease,
      builder: (_, v, _) => ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: Container(
          height: 4,
          color: TP.track,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(widthFactor: v, child: Container(color: TP.primary)),
        ),
      ),
    );
  }
}

bool _validEmail(String s) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s.trim());

class _AuthFrame extends StatelessWidget {
  const _AuthFrame({required this.title, required this.sub, required this.children});
  final String title;
  final String sub;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final form = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 32),
          children: [
            Row(children: [
              const LogoMark(size: 44),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Therapy Pal', style: tpText(18, w: FontWeight.w700, ls: -0.3)),
                Text('Treatment Regimen', style: barSub),
              ]),
            ]),
            const SizedBox(height: 28),
            Text(title, style: pageTitle),
            const SizedBox(height: 8),
            Text(sub, style: tpText(14.5, color: TP.muted, h: 1.5)),
            const SizedBox(height: 22),
            ...children,
          ],
        ),
      ),
    );
    final split = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      backgroundColor: TP.ground,
      body: SafeArea(
        child: split
            ? Row(children: [
                Expanded(flex: 11, child: form),
                Expanded(flex: 9, child: const Padding(padding: EdgeInsets.all(16), child: _BrandPanel())),
              ])
            : form,
      ),
    );
  }
}

/// Wide-screen side panel next to the sign-in / sign-up form.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    Widget point(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 19, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(child: Padding(padding: const EdgeInsets.only(top: 7), child: Text(text, style: tpText(15, w: FontWeight.w600, color: Colors.white, h: 1.35)))),
          ]),
        );
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TP.radiusXl),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [TP.primary, TP.primary700]),
      ),
      padding: const EdgeInsets.all(40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: const LogoMark(size: 48),
            ),
            const SizedBox(height: 28),
            Text('Your treatment regimen, in one calm place.', style: tpText(30, w: FontWeight.w700, color: Colors.white, ls: -0.6, h: 1.2)),
            const SizedBox(height: 12),
            Text('Track doses, follow your schedule and stay in touch with your care team.', style: tpText(15, color: Colors.white.withValues(alpha: .85), h: 1.5)),
            const SizedBox(height: 28),
            point(Icons.schedule, 'A daily dose schedule with reminders'),
            point(Icons.trending_up, 'Adherence you can see at a glance'),
            point(Icons.chat_bubble_outline, 'Direct messages with your clinician'),
          ]),
        ),
      ),
    );
  }
}

class _FormError extends StatelessWidget {
  const _FormError(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: TP.dangerBg, borderRadius: BorderRadius.circular(TP.radiusSm)),
        child: Row(children: [
          const Icon(Icons.error_outline, size: 18, color: TP.danger),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: tpText(13.5, w: FontWeight.w600, color: TP.danger, h: 1.4))),
        ]),
      );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _demo = {'patient': 'alex.rivera@email.com', 'clinician': 's.carter@downtownclinic.org'};
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _role = 'patient';
  String? _emailErr, _pwErr, _formErr;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Demo credentials are pre-filled in debug builds only (matches the design).
    if (kDebugMode) {
      _email.text = _demo['patient']!;
      _password.text = 'therapy-pal';
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _setRole(String r) {
    setState(() {
      if (kDebugMode && _demo.containsValue(_email.text.trim())) _email.text = _demo[r]!;
      _role = r;
      _formErr = null;
    });
  }

  Future<void> _submit() async {
    final emailBad = !_validEmail(_email.text);
    final pwBad = _password.text.length < 4;
    setState(() {
      _emailErr = emailBad ? 'Enter the email address for your account.' : null;
      _pwErr = pwBad ? 'Password must be at least 4 characters.' : null;
      _formErr = null;
    });
    if (emailBad || pwBad) return;
    setState(() => _busy = true);
    try {
      await context.read<Session>().login(_email.text.trim(), _password.text, _role);
      // The router redirects to the correct home on success.
    } on ApiException catch (e) {
      if (mounted) setState(() => _formErr = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthFrame(
      title: 'Welcome back',
      sub: 'Sign in to follow your regimen or manage your patient panel.',
      children: [
        Seg(options: const [('patient', 'Patient'), ('clinician', 'Clinician')], value: _role, onChanged: _setRole),
        const SizedBox(height: 16),
        TpField(label: 'Email', controller: _email, keyboard: TextInputType.emailAddress, error: _emailErr, autofillHints: const [AutofillHints.username]),
        const SizedBox(height: 16),
        TpField(label: 'Password', controller: _password, obscure: true, error: _pwErr, autofillHints: const [AutofillHints.password]),
        if (_formErr != null) ...[const SizedBox(height: 16), _FormError(_formErr!)],
        const SizedBox(height: 16),
        TpButton('Sign in', onPressed: _submit, block: true, loading: _busy),
        const SizedBox(height: 14),
        Center(
          child: TextButton(
            onPressed: () => context.go('/register'),
            child: Text.rich(TextSpan(children: [
              TextSpan(text: 'New here?  ', style: tpText(13.5, color: TP.muted)),
              TextSpan(text: 'Create an account', style: tpText(13.5, w: FontWeight.w700, color: TP.primary)),
            ])),
          ),
        ),
      ],
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _clinicianEmail = TextEditingController();
  final _npi = TextEditingController();
  final _spec = TextEditingController();
  String _role = 'patient';
  final Map<String, String> _errors = {};
  String? _formErr;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _phone, _clinicianEmail, _npi, _spec]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final e = <String, String>{};
    if (_name.text.trim().length < 2) e['name'] = 'Enter your full name.';
    if (!_validEmail(_email.text)) e['email'] = 'Enter a valid email address.';
    if (_password.text.length < 8) e['password'] = 'Password must be at least 8 characters.';
    if (_role == 'clinician') {
      if (!RegExp(r'^\d{10}$').hasMatch(_npi.text.trim())) e['npi'] = 'NPI must be 10 digits.';
      if (_spec.text.trim().length < 2) e['spec'] = 'Enter your specialization.';
    } else if (_clinicianEmail.text.trim().isNotEmpty && !_validEmail(_clinicianEmail.text)) {
      e['clinicianEmail'] = 'Enter a valid email address.';
    }
    setState(() {
      _errors
        ..clear()
        ..addAll(e);
      _formErr = null;
    });
    if (e.isNotEmpty) return;

    final body = <String, dynamic>{
      'role': _role,
      'name': _name.text.trim(),
      'email': _email.text.trim(),
      'password': _password.text,
      if (_role == 'patient') ...{
        if (_phone.text.trim().isNotEmpty) 'phone': _phone.text.trim(),
        if (_clinicianEmail.text.trim().isNotEmpty) 'clinicianEmail': _clinicianEmail.text.trim(),
      } else ...{
        'npi': _npi.text.trim(),
        'specialization': _spec.text.trim(),
      },
    };
    setState(() => _busy = true);
    try {
      await context.read<Session>().register(body);
    } on ApiException catch (ex) {
      if (mounted) setState(() => _formErr = ex.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patient = _role == 'patient';
    Widget gap() => const SizedBox(height: 16);
    return _AuthFrame(
      title: 'Create your account',
      sub: patient ? 'Track your regimen and stay in touch with your care team.' : 'Monitor adherence across your patient panel.',
      children: [
        Seg(options: const [('patient', 'Patient'), ('clinician', 'Clinician')], value: _role, onChanged: (r) => setState(() => _role = r)),
        gap(),
        TpField(label: 'Full name', controller: _name, error: _errors['name'], autofillHints: const [AutofillHints.name]),
        gap(),
        TpField(label: 'Email', controller: _email, keyboard: TextInputType.emailAddress, error: _errors['email'], autofillHints: const [AutofillHints.email]),
        gap(),
        TpField(label: 'Password', controller: _password, obscure: true, error: _errors['password'], hint: 'At least 8 characters'),
        gap(),
        if (patient) ...[
          TpField(label: 'Phone', controller: _phone, keyboard: TextInputType.phone, optional: true),
          gap(),
          TpField(label: "Clinician's email", controller: _clinicianEmail, keyboard: TextInputType.emailAddress, optional: true, error: _errors['clinicianEmail'], hint: 'Links you to your care team'),
        ] else ...[
          TpField(label: 'NPI number', controller: _npi, keyboard: TextInputType.number, error: _errors['npi'], hint: '10 digits'),
          gap(),
          TpField(label: 'Specialization', controller: _spec, error: _errors['spec']),
        ],
        if (_formErr != null) ...[gap(), _FormError(_formErr!)],
        gap(),
        TpButton('Create account', onPressed: _submit, block: true, loading: _busy),
        const SizedBox(height: 14),
        Center(
          child: TextButton(
            onPressed: () => context.go('/login'),
            child: Text.rich(TextSpan(children: [
              TextSpan(text: 'Already have an account?  ', style: tpText(13.5, color: TP.muted)),
              TextSpan(text: 'Sign in', style: tpText(13.5, w: FontWeight.w700, color: TP.primary)),
            ])),
          ),
        ),
      ],
    );
  }
}

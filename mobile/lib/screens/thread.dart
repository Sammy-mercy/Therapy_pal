import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/format.dart';
import '../core/tokens.dart';
import '../state/session.dart';
import '../widgets/ui.dart';

/// Clinician <-> patient conversation. Works for both roles; v1 refreshes every 10s (no sockets).
class ThreadPage extends StatefulWidget {
  const ThreadPage({super.key, required this.patientId, required this.subtitle, this.backTo, this.embedded = false});
  final String patientId;
  final String? backTo;
  final String subtitle;

  /// Shown inside a split view (no back button, framed as a panel).
  final bool embedded;

  @override
  State<ThreadPage> createState() => _ThreadPageState();
}

class _ThreadPageState extends State<ThreadPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  List<Json> _messages = [];
  Json? _with;
  Object? _error;
  bool _loading = true;
  bool _sending = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final api = context.read<Api>();
    final role = context.read<Session>().role;
    final badges = context.read<Badges>();
    try {
      final res = await api.get('/messages/threads/${widget.patientId}');
      if (!mounted) return;
      final next = (res['messages'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final grew = next.length != _messages.length;
      setState(() {
        _messages = next;
        _with = Map<String, dynamic>.from(res['with'] as Map);
        _error = null;
        _loading = false;
      });
      if (grew) _toBottom();
      badges.refresh(role);
    } catch (e) {
      if (!mounted || silent) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: TP.speed, curve: TP.ease);
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    final api = context.read<Api>();
    setState(() => _sending = true);
    try {
      final res = await api.post('/messages/threads/${widget.patientId}', {'text': text});
      final m = Map<String, dynamic>.from(res['message'] as Map);
      if (!mounted) return;
      setState(() => _messages = [..._messages, m]);
      _input.clear();
      _toBottom();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final header = PageHeader(backTo: widget.embedded ? null : widget.backTo, title: (_with?['name'] as String?) ?? 'Conversation', sub: widget.subtitle, dense: widget.embedded);
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator(color: TP.primary));
    } else if (_error != null) {
      body = ErrorBlock(message: _error is ApiException ? (_error as ApiException).message : 'Something went wrong.', onRetry: () {
        setState(() => _loading = true);
        _load();
      });
    } else if (_messages.isEmpty) {
      body = Padding(padding: const EdgeInsets.all(16), child: EmptyCard('No messages with ${(_with?['name'] as String?) ?? 'them'} yet.\nSend the first message to start the conversation.'));
    } else {
      body = ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        itemCount: _messages.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _Bubble(_messages[i]),
      );
    }
    final panel = Column(children: [
        header,
        if (widget.embedded) const Divider(height: 1, color: TP.line),
        Expanded(child: body),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          decoration: const BoxDecoration(color: TP.surface, border: Border(top: BorderSide(color: TP.line))),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                maxLength: 2000,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                style: tpText(15),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'Write a message\u2026',
                  hintStyle: tpText(15, color: const Color(0xFF8A9BA0)),
                  filled: true,
                  fillColor: TP.ground,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: TP.line)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: TP.line)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: const BorderSide(color: TP.primary, width: 2)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: 'Send message',
              child: Material(
                color: TP.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _sending ? null : _send,
                  child: SizedBox(
                    width: 46,
                    height: 46,
                    child: _sending
                        ? const Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ]),
        ),
    ]);
    if (widget.embedded) {
      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: TP.surface, borderRadius: BorderRadius.circular(TP.radius), border: Border.all(color: TP.line), boxShadow: TP.shadow),
        child: panel,
      );
    }
    return SafeArea(
      bottom: false,
      child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 860), child: panel)),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.m);
  final Json m;

  @override
  Widget build(BuildContext context) {
    final me = m['from'] == 'me';
    final max = MediaQuery.sizeOf(context).width * 0.8;
    return Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: max),
        child: Column(crossAxisAlignment: me ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: me ? TP.primary : TP.surface,
              border: me ? null : Border.all(color: TP.line),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(me ? 16 : 6),
                bottomRight: Radius.circular(me ? 6 : 16),
              ),
            ),
            child: Text('${m['text']}', style: tpText(14.5, color: me ? Colors.white : TP.ink, h: 1.45)),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
            child: Text('${me ? 'You \u00b7 ' : ''}${relTime('${m['createdAt']}')}', style: tpText(11, w: FontWeight.w600, color: TP.muted)),
          ),
        ]),
      ),
    );
  }
}

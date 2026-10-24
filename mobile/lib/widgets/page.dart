import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/responsive.dart';
import '../core/tokens.dart';
import 'ui.dart';

/// Loads data once, shows a spinner / error state, and exposes a silent [reload] to the builder.
class Loader<T> extends StatefulWidget {
  const Loader({super.key, required this.load, required this.builder, this.loadingHeader});
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;
  final Widget? loadingHeader;

  @override
  State<Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<Loader<T>> {
  T? _data;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final d = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = d;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (silent && _data != null) {
        toast(context, e is ApiException ? e.message : 'Could not refresh', error: true);
        return;
      }
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_data != null) return widget.builder(context, _data as T, () => _run(silent: true));
    final body = _loading
        ? const Center(child: CircularProgressIndicator(color: TP.primary))
        : ErrorBlock(message: _error is ApiException ? (_error as ApiException).message : 'Something went wrong.', onRetry: _run);
    return SafeArea(
      bottom: false,
      child: Column(children: [
        if (widget.loadingHeader != null) widget.loadingHeader!,
        Expanded(child: body),
      ]),
    );
  }
}

/// Header + scrollable body (+ optional pinned footer), inside the safe area.
/// Content is centred and capped at [maxWidth] on wide screens; gutters follow the design (16/24/32).
class PageScaffold extends StatelessWidget {
  const PageScaffold({super.key, required this.header, required this.children, this.onRefresh, this.footer, this.maxWidth = 1200});
  final Widget header;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final Widget? footer;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final gutter = pageGutter(context.screenSize);
    return LayoutBuilder(builder: (context, c) {
      final side = math.max(gutter, (c.maxWidth - maxWidth) / 2);
      Widget list = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(side, 4, side, 32),
        children: children,
      );
      if (onRefresh != null) list = RefreshIndicator(color: TP.primary, onRefresh: onRefresh!, child: list);
      return SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(padding: EdgeInsets.symmetric(horizontal: side - 16), child: header),
          Expanded(child: list),
          ?footer,
        ]),
      );
    });
  }
}

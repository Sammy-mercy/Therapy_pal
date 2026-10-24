import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/responsive.dart';
import '../core/tokens.dart';

/// Tests set this to avoid downloading fonts.
bool tpUseDeviceFonts = false;

TextStyle tpText(double size, {FontWeight w = FontWeight.w500, Color color = TP.ink, double? ls, double? h}) => tpUseDeviceFonts
    ? TextStyle(fontSize: size, fontWeight: w, color: color, letterSpacing: ls, height: h)
    : GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: w, color: color, letterSpacing: ls, height: h);

TextStyle get barTitle => tpText(20, w: FontWeight.w700, ls: -0.4, h: 1.2);
TextStyle get barSub => tpText(12.5, color: TP.muted);
TextStyle get pageTitle => tpText(26, w: FontWeight.w700, ls: -0.8, h: 1.15);
TextStyle get sectionTitle => tpText(16, w: FontWeight.w700, ls: -0.16);
TextStyle get rowTitle => tpText(15, w: FontWeight.w600, ls: -0.08);
TextStyle get rowSub => tpText(12.5, color: TP.muted);
TextStyle get mutedSm => tpText(12.5, w: FontWeight.w600, color: TP.muted);
TextStyle get eyebrow => tpText(11, w: FontWeight.w700, color: TP.muted, ls: 1);

void toast(BuildContext context, String msg, {bool error = false}) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: error ? TP.danger : TP.ink,
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TP.radiusSm)),
    duration: const Duration(milliseconds: 2600),
    content: Row(children: [
      Icon(error ? Icons.error_outline : Icons.check, color: Colors.white, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(msg, style: tpText(14, w: FontWeight.w600, color: Colors.white))),
    ]),
  ));
}

/// Card with the design's border, radius and soft shadow.
class TpCard extends StatelessWidget {
  const TpCard({super.key, required this.child, this.padding = EdgeInsets.zero, this.onTap, this.color});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(TP.radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? TP.surface,
        borderRadius: r,
        border: Border.all(color: TP.line),
        boxShadow: TP.shadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: r,
          onTap: onTap,
          hoverColor: TP.primary050,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class RowItem extends StatelessWidget {
  const RowItem({super.key, required this.leading, required this.title, this.subs = const [], this.trailing, this.onTap, this.subLines = 1, this.selected = false});
  final Widget leading;
  final String title;
  final List<String> subs;
  final Widget? trailing;
  final VoidCallback? onTap;
  final int subLines;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return TpCard(
      onTap: onTap,
      color: selected ? TP.primary050 : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(children: [
        leading,
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: rowTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
            for (final s in subs)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(s, style: rowSub, maxLines: subLines, overflow: TextOverflow.ellipsis),
              ),
          ]),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ]),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar(this.initials, {super.key, this.size = 42});
  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [TP.primary, TP.primary700]),
      ),
      child: Text(initials, style: tpText(size * 0.32, w: FontWeight.w700, color: Colors.white, ls: 0.3)),
    );
  }
}

enum TagKind { active, inactive, info, warn, danger }

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.kind = TagKind.info});
  final String text;
  final TagKind kind;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      TagKind.active => (TP.successBg, TP.success),
      TagKind.inactive => (TP.neutralBg, TP.muted),
      TagKind.info => (TP.primary050, TP.primary700),
      TagKind.warn => (TP.warnBg, TP.warn),
      TagKind.danger => (TP.dangerBg, TP.danger),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: tpText(11, w: FontWeight.w700, color: fg, ls: 0.1)),
    );
  }
}

Color tierColor(int? rate) => rate == null ? TP.muted : rate >= 80 ? TP.success : rate >= 65 ? TP.warn : TP.danger;
Color tierBg(int? rate) => rate == null ? TP.neutralBg : rate >= 80 ? TP.successBg : rate >= 65 ? TP.warnBg : TP.dangerBg;

class RatePill extends StatelessWidget {
  const RatePill(this.rate, {super.key});
  final int? rate;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 52),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tierBg(rate), borderRadius: BorderRadius.circular(99)),
      child: Text(rate == null ? '\u2014' : '$rate%',
          style: tpText(12.5, w: FontWeight.w700, color: tierColor(rate)).copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
    );
  }
}

class SectionHead extends StatelessWidget {
  const SectionHead(this.title, {super.key, this.trailing, this.top = 24});
  final String title;
  final Widget? trailing;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: 10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 34),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: Text(title, style: sectionTitle)),
          ?trailing,
        ]),
      ),
    );
  }
}

enum IconKind { primary, therapy, danger, neutral }

class TypeIcon extends StatelessWidget {
  const TypeIcon(this.icon, {super.key, this.kind = IconKind.primary});
  final IconData icon;
  final IconKind kind;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (kind) {
      IconKind.primary => (TP.primary050, TP.primary700),
      IconKind.therapy => (TP.therapyBg, TP.therapyFg),
      IconKind.danger => (TP.dangerBg, TP.danger),
      IconKind.neutral => (TP.neutralBg, TP.muted),
    };
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13)),
      child: Icon(icon, color: fg, size: 21),
    );
  }
}

class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 84});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/Treatment_Regimen_logo-Primary_color.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

/// Square outlined icon button with an optional red count badge.
class IconBox extends StatelessWidget {
  const IconBox({super.key, required this.icon, required this.onTap, this.badge = 0, this.label, this.bare = false});
  final IconData icon;
  final VoidCallback onTap;
  final int badge;
  final String? label;
  final bool bare;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(TP.radiusSm);
    return Semantics(
      button: true,
      label: label == null ? null : (badge > 0 ? '$label, $badge unread' : label),
      child: SizedBox(
        width: bare ? 40 : 44,
        height: bare ? 40 : 44,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(
            child: Material(
              color: bare ? Colors.transparent : TP.surface,
              shape: RoundedRectangleBorder(borderRadius: r, side: bare ? BorderSide.none : const BorderSide(color: TP.line)),
              child: InkWell(borderRadius: r, onTap: onTap, child: Icon(icon, size: 20, color: TP.ink)),
            ),
          ),
          if (badge > 0)
            Positioned(
              top: 5,
              right: 5,
              child: Container(
                constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: TP.danger, borderRadius: BorderRadius.circular(99), border: Border.all(color: TP.surface, width: 2)),
                child: Text('$badge', style: tpText(10, w: FontWeight.w700, color: Colors.white)),
              ),
            ),
        ]),
      ),
    );
  }
}

/// The design's page header: optional back button or avatar, title/subtitle, trailing actions.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.sub, this.avatar, this.backTo, this.actions = const [], this.dense = false});
  final String title;
  final String? sub;
  final String? avatar;
  final String? backTo;
  final List<Widget> actions;

  /// Phone-sized header even on wide screens (used inside panels).
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final big = context.isWide && !dense;
    Widget? left;
    if (backTo != null) {
      left = IconBox(
        icon: Icons.chevron_left,
        bare: true,
        label: 'Back',
        onTap: () => context.canPop() ? context.pop() : context.go(backTo!),
      );
    } else if (avatar != null) {
      left = Avatar(avatar!, size: 34);
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(16, big ? 20 : 8, 16, big ? 18 : 12),
      child: Row(children: [
        if (left != null) ...[left, const SizedBox(width: 12)],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: big ? tpText(28, w: FontWeight.w700, ls: -0.6, h: 1.2) : barTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (sub != null) Text(sub!, style: big ? tpText(14, color: TP.muted) : barSub, maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
        for (final a in actions) ...[const SizedBox(width: 8), a],
      ]),
    );
  }
}

class LinkBtn extends StatelessWidget {
  const LinkBtn(this.label, {super.key, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(foregroundColor: TP.primary, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        child: Text(label, style: tpText(13.5, w: FontWeight.w700, color: TP.primary)),
      );
}

enum BtnKind { primary, ghost, danger }

class TpButton extends StatelessWidget {
  const TpButton(this.label, {super.key, required this.onPressed, this.icon, this.kind = BtnKind.primary, this.block = false, this.small = false, this.loading = false});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final BtnKind kind;
  final bool block;
  final bool small;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final h = small ? 38.0 : 48.0;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(small ? 12 : TP.radiusSm));
    final padding = EdgeInsets.symmetric(horizontal: small ? 14 : 18);
    final size = Size(block ? double.infinity : 0, h);
    final textStyle = tpText(small ? 13.5 : 15, w: FontWeight.w600, ls: -0.1);
    final fg = switch (kind) { BtnKind.primary => Colors.white, BtnKind.ghost => TP.ink, BtnKind.danger => TP.danger };
    final child = loading
        ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
        : Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, size: small ? 16 : 18), const SizedBox(width: 8)],
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]);
    final cb = loading ? null : onPressed;
    if (kind == BtnKind.ghost) {
      return OutlinedButton(
        onPressed: cb,
        style: OutlinedButton.styleFrom(backgroundColor: TP.surface, foregroundColor: TP.ink, side: const BorderSide(color: TP.line), minimumSize: size, padding: padding, shape: shape, textStyle: textStyle),
        child: child,
      );
    }
    return FilledButton(
      onPressed: cb,
      style: FilledButton.styleFrom(
        backgroundColor: kind == BtnKind.primary ? TP.primary : TP.dangerBg,
        foregroundColor: fg,
        disabledBackgroundColor: (kind == BtnKind.primary ? TP.primary : TP.dangerBg).withValues(alpha: .5),
        disabledForegroundColor: fg.withValues(alpha: .8),
        minimumSize: size,
        padding: padding,
        shape: shape,
        textStyle: textStyle,
      ),
      child: child,
    );
  }
}

class ChipRow extends StatelessWidget {
  const ChipRow({super.key, required this.items, required this.current, required this.onSelected});
  final List<(String, String)> items;
  final String current;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (value, label) = items[i];
          final on = value == current;
          return Semantics(
            button: true,
            selected: on,
            child: Material(
              color: on ? TP.primary : TP.surface,
              shape: StadiumBorder(side: BorderSide(color: on ? TP.primary : TP.line)),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => onSelected(value),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Center(child: Text(label, style: tpText(13, w: FontWeight.w600, color: on ? Colors.white : TP.ink2))),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Two-or-more option segmented control matching the design's `.seg`.
class Seg extends StatelessWidget {
  const Seg({super.key, required this.options, required this.value, required this.onChanged});
  final List<(String, String)> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: TP.segBg, borderRadius: BorderRadius.circular(TP.radiusSm)),
      child: Row(children: [
        for (final (v, label) in options)
          Expanded(
            child: Semantics(
              button: true,
              selected: v == value,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: TP.speed,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: v == value ? TP.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: v == value ? const [BoxShadow(color: Color(0x2910242A), blurRadius: 3, offset: Offset(0, 1))] : null,
                  ),
                  child: Text(label, style: tpText(14, w: FontWeight.w700, color: v == value ? TP.ink : TP.muted)),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

class KvList extends StatelessWidget {
  const KvList(this.rows, {super.key});
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (var i = 0; i < rows.length; i++)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(border: i == rows.length - 1 ? null : const Border(bottom: BorderSide(color: TP.line))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(rows[i].$1, style: tpText(13, w: FontWeight.w600, color: TP.muted)),
            const SizedBox(width: 14),
            Flexible(child: Text(rows[i].$2, textAlign: TextAlign.right, style: tpText(14, w: FontWeight.w600))),
          ]),
        ),
    ]);
  }
}

class EmptyCard extends StatelessWidget {
  const EmptyCard(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => TpCard(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
        child: SizedBox(width: double.infinity, child: Text(text, textAlign: TextAlign.center, style: tpText(13.5, color: TP.muted, h: 1.5))),
      );
}

class ErrorBlock extends StatelessWidget {
  const ErrorBlock({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const TypeIcon(Icons.cloud_off_outlined, kind: IconKind.danger),
          const SizedBox(height: 14),
          Text(message, textAlign: TextAlign.center, style: tpText(14, color: TP.ink2, h: 1.5)),
          const SizedBox(height: 16),
          TpButton('Try again', onPressed: onRetry, kind: BtnKind.ghost, small: true, icon: Icons.refresh),
        ]),
      ),
    );
  }
}

/// Labeled form field with the design's input styling and an inline error line.
class TpField extends StatelessWidget {
  const TpField({super.key, required this.label, required this.controller, this.keyboard, this.obscure = false, this.error, this.hint, this.maxLines = 1, this.autofillHints, this.onChanged, this.optional = false});
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboard;
  final bool obscure;
  final String? error;
  final String? hint;
  final int maxLines;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(TP.radiusSm), borderSide: BorderSide(color: c, width: w));
    final bad = error != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text.rich(TextSpan(children: [
        TextSpan(text: label, style: tpText(13, w: FontWeight.w700, color: TP.ink2)),
        if (optional) TextSpan(text: '  optional', style: tpText(13, color: TP.muted)),
      ])),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        keyboardType: keyboard,
        obscureText: obscure,
        maxLines: obscure ? 1 : maxLines,
        autofillHints: autofillHints,
        onChanged: onChanged,
        style: tpText(15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: tpText(15, color: const Color(0xFF8A9BA0)),
          filled: true,
          fillColor: TP.surface,
          isDense: false,
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: maxLines > 1 ? 12 : 14),
          enabledBorder: border(bad ? TP.danger : TP.line),
          focusedBorder: border(bad ? TP.danger : TP.primary, 2),
          border: border(TP.line),
        ),
      ),
      if (bad) Padding(padding: const EdgeInsets.only(top: 6), child: Text(error!, style: tpText(12.5, w: FontWeight.w600, color: TP.danger))),
    ]);
  }
}

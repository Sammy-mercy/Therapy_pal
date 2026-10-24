import 'package:flutter/material.dart';

/// Design tokens. Colours, radii and shadows follow the responsive web template (DESIGN.md).
class TP {
  static const primary = Color(0xFF0C7B85);
  static const primary700 = Color(0xFF095D66);
  static const primary050 = Color(0xFFE9F5F6);
  static const primary100 = Color(0xFFD6ECEE);
  static const ink = Color(0xFF10242A);
  static const ink2 = Color(0xFF38505A);
  static const muted = Color(0xFF54686E);
  static const line = Color(0xFFDCE8EA);
  static const ground = Color(0xFFF1FBFF);
  static const surface = Color(0xFFFFFFFF);
  static const success = Color(0xFF1A8754);
  static const successBg = Color(0xFFE8F6EF);
  static const warn = Color(0xFFC57B18);
  static const warnBg = Color(0xFFFEF7EB);
  static const danger = Color(0xFFC83E4D);
  static const dangerBg = Color(0xFFFDEEF0);
  static const track = Color(0xFFDCEBEF);
  static const neutralBg = Color(0xFFECF3F4);
  static const segBg = Color(0xFFDDEEF2);
  static const therapyBg = Color(0xFFEAF3FB);
  static const therapyFg = Color(0xFF1D5E8F);

  static const radius = 16.0; // cards & panels
  static const radiusSm = 10.0; // inputs, buttons, tabs
  static const radiusXl = 24.0; // sheets, dialogs
  static const speed = Duration(milliseconds: 200);
  static const ease = Cubic(.22, .61, .36, 1);

  static const shadow = [
    BoxShadow(color: Color(0x0A10242A), blurRadius: 8, spreadRadius: -2, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x0510242A), blurRadius: 2, offset: Offset(0, 1)),
  ];
}

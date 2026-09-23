import 'package:flutter/material.dart';

class AppShadows {
  static const List<BoxShadow> soft = [
    BoxShadow(color: Color(0x24000000), blurRadius: 24, offset: Offset(0, 12)),
    BoxShadow(
      color: Color(0x12B26BFF),
      blurRadius: 32,
      spreadRadius: -8,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> glow = [
    BoxShadow(
      color: Color(0x44B26BFF),
      blurRadius: 24,
      spreadRadius: 0,
      offset: Offset(0, 8),
    ),
  ];
}

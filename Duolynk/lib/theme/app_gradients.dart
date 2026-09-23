import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppGradients {
  static const LinearGradient primary = LinearGradient(
    colors: [AppColors.primaryStart, AppColors.primaryEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGlow = LinearGradient(
    colors: [Color(0x66FF3E9E), Color(0x66B26BFF), Color(0x337B2FFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardHighlight = LinearGradient(
    colors: [Color(0x1FFFFFFF), Color(0x05FFFFFF), Color(0x12B26BFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const RadialGradient backgroundHalo = RadialGradient(
    colors: [Color(0x22B26BFF), Color(0x11FF3E9E), Color(0x000A0A12)],
    stops: [0, 0.45, 1],
  );
}

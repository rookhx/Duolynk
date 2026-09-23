import 'package:flutter/material.dart';

class DuolynkThemeExtension extends ThemeExtension<DuolynkThemeExtension> {
  const DuolynkThemeExtension({
    required this.screenPadding,
    required this.sectionSpacing,
    required this.cardBlur,
  });

  final double screenPadding;
  final double sectionSpacing;
  final double cardBlur;

  @override
  ThemeExtension<DuolynkThemeExtension> copyWith({
    double? screenPadding,
    double? sectionSpacing,
    double? cardBlur,
  }) {
    return DuolynkThemeExtension(
      screenPadding: screenPadding ?? this.screenPadding,
      sectionSpacing: sectionSpacing ?? this.sectionSpacing,
      cardBlur: cardBlur ?? this.cardBlur,
    );
  }

  @override
  ThemeExtension<DuolynkThemeExtension> lerp(
    covariant ThemeExtension<DuolynkThemeExtension>? other,
    double t,
  ) {
    if (other is! DuolynkThemeExtension) {
      return this;
    }

    return DuolynkThemeExtension(
      screenPadding: Tween<double>(
        begin: screenPadding,
        end: other.screenPadding,
      ).transform(t),
      sectionSpacing: Tween<double>(
        begin: sectionSpacing,
        end: other.sectionSpacing,
      ).transform(t),
      cardBlur: Tween<double>(
        begin: cardBlur,
        end: other.cardBlur,
      ).transform(t),
    );
  }
}

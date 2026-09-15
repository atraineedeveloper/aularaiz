import 'package:flutter/widgets.dart';

final class ResponsiveLayoutInfo {
  const ResponsiveLayoutInfo._({required this.size, required this.textScale});

  factory ResponsiveLayoutInfo.of(BuildContext context) {
    return ResponsiveLayoutInfo._(
      size: MediaQuery.sizeOf(context),
      textScale: MediaQuery.textScalerOf(context).scale(1),
    );
  }

  final Size size;
  final double textScale;

  bool get isLandscape => size.width > size.height;
  bool get isPhone => size.shortestSide < 600;
  bool get isPhoneLandscape => isPhone && isLandscape;
  bool get isCompactWidth => size.width < 600;
  bool get hasTightHeight => size.height < 520;
  bool get hasLargeText => textScale >= 1.4;
  bool get preferDenseUi => isPhoneLandscape || hasTightHeight || hasLargeText;

  double get pagePadding => preferDenseUi ? 12 : (isCompactWidth ? 16 : 20);
}

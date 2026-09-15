import 'package:flutter/material.dart';

class ResponsiveBreakpoints {
  static const double compact = 600;
  static const double medium = 840;
  static const double expanded = 1200;

  static bool isCompact(BuildContext context) =>
      MediaQuery.of(context).size.width < compact;

  static bool isMedium(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= compact && width < expanded;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= medium;

  static bool isExpanded(BuildContext context) =>
      MediaQuery.of(context).size.width >= expanded;
}

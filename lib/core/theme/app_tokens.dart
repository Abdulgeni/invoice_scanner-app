import 'package:flutter/widgets.dart';

/// 4pt spacing scale.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

abstract final class AppRadii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

abstract final class AppSizes {
  static const double minTouchTarget = 48;
  static const double buttonMinWidth = 64;
  static const double iconSm = 20;
  static const double iconMd = 24;
  static const double iconLg = 32;
  static const double iconXl = 56;
  static const double pageDot = 8;
  static const double pageDotActive = 24;
  static const double thumbnail = 120;
  static const double maxContentWidth = 640;

  static const double pageAspectRatio = 210 / 297;
  static const int pageStackMaxVisible = 3;
  static const double pageStackOffset = 10;
  static const double sweepBandFraction = 0.28;
  static const double sweepLineWidth = 2;
  static const double stageSegmentHeight = 4;
  static const double failurePreviewHeight = 200;
  static const double reviewTwoPaneMinWidth = 840;
  static const double scanPanelHeight = 320;
  static const double checkBadge = 96;
  static const double noteIcon = 20;
}

abstract final class AppElevation {
  static const double flat = 0;
  static const double raised = 1;
  static const double overlay = 3;
}

abstract final class AppShadows {
  static const List<BoxShadow> soft = <BoxShadow>[
    BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 4)),
  ];
}

const bool kHapticsEnabled = true;

abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
  static const Curve exit = Curves.easeInCubic;

  static const double pressScale = 0.97;
  static const double pulseMinScale = 0.92;

  static const Duration sweepCycle = Duration(milliseconds: 2200);
  static const Duration completionBeat = Duration(milliseconds: 700);
  static const Duration checkDraw = Duration(milliseconds: 700);

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static Duration resolve(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}

abstract final class AppZoom {
  static const double min = 1;
  static const double max = 4;
  static const double epsilon = 0.01;
}

abstract final class AppOpacity {
  static const double dimScrim = 0.45;
  static const double sweepTrail = 0.28;
  static const double sweepLine = 0.9;
}

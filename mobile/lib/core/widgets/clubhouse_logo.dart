import 'package:flutter/material.dart';

/// Marquee text-style wordmark used on the home hero, login, and signup.
///
/// "CLUBHOUSE" sits on top in white. A thin gold rule separates it from the
/// gold "STAKES" wordmark below. A small "PRIZE POOL GOLF" tagline anchors
/// the bottom. Designed to sit on the dark green hero gradient.
class ClubhouseLogo extends StatelessWidget {
  final double width;
  final bool showTagline;
  final Color primaryColor;
  final Color accentColor;

  const ClubhouseLogo({
    super.key,
    this.width = 280,
    this.showTagline = true,
    this.primaryColor = Colors.white,
    this.accentColor = const Color(0xFFC9A84C),
  });

  @override
  Widget build(BuildContext context) {
    // Scale typography off the requested width so the logo stays balanced
    // on tiny avatar uses (width=80) and large hero uses (width=320).
    final clubhouseSize = width * 0.155;
    final stakesSize    = width * 0.155;
    final taglineSize   = width * 0.034;
    final ruleWidth     = width * 0.55;

    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // FittedBox auto-shrinks each line to fit the available width so
          // letter-spacing never pushes the wordmark onto two lines.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'CLUBHOUSE',
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                color: primaryColor,
                fontSize: clubhouseSize,
                fontWeight: FontWeight.w900,
                letterSpacing: clubhouseSize * 0.14,
                height: 1.0,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: width * 0.012),
            child: Container(
              width: ruleWidth,
              height: 2,
              color: accentColor,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'STAKES',
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                color: accentColor,
                fontSize: stakesSize,
                fontWeight: FontWeight.w900,
                letterSpacing: stakesSize * 0.28,
                height: 1.0,
              ),
            ),
          ),
          if (showTagline) ...[
            SizedBox(height: width * 0.026),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'PRIZE POOL GOLF',
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: primaryColor.withOpacity(0.55),
                  fontSize: taglineSize,
                  fontWeight: FontWeight.w600,
                  letterSpacing: taglineSize * 0.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

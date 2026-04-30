import 'package:flutter/material.dart';

class ClubhouseLogo extends StatelessWidget {
  final double width;

  const ClubhouseLogo({super.key, this.width = 260});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
      decoration: BoxDecoration(
        color: const Color(0xFF1B3D2C),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFC9A84C), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Trophy with flag
          Stack(
            alignment: Alignment.center,
            children: [
              const Icon(
                Icons.emoji_events_rounded,
                color: Color(0xFFC9A84C),
                size: 56,
              ),
              Positioned(
                right: 0,
                top: 6,
                child: Container(
                  width: 3,
                  height: 18,
                  color: const Color(0xFFC9A84C),
                ),
              ),
              Positioned(
                right: 3,
                top: 6,
                child: Container(
                  width: 10,
                  height: 8,
                  color: const Color(0xFFC9A84C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'CLUBHOUSE STAKES',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.5,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'PRIZE POOL GOLF TOURNAMENTS',
            style: TextStyle(
              color: Color(0xFFC9A84C),
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';

void showToast(BuildContext context, String message) {
  final overlay = Overlay.of(context);

  final entry = OverlayEntry(
    builder: (_) {
      return Animate(
        effects: [
          SlideEffect(end: Offset(0, -1), curve: Curves.easeOut),
          SlideEffect(
            end: Offset(0, 2),
            curve: Curves.easeOut,
            delay: Duration(seconds: 2),
          ),
        ],
        child: Positioned(
          bottom: -20,
          left: 20,
          right: 20,
          child: CupertinoPopupSurface(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                message,
                style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    },
  );

  overlay.insert(entry);
  Future.delayed(const Duration(seconds: 3), () => entry.remove());
}

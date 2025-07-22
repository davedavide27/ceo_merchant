import 'dart:ui';
import 'package:flutter/material.dart';

class LoadingAnimation extends StatelessWidget {
  final bool isVisible;
  final String message;

  const LoadingAnimation({
    super.key,
    required this.isVisible,
    this.message = 'Connecting to server...',
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. transparent layer – guarantees we add no tint
        const ColoredBox(color: Colors.transparent),

        // 2. blur what’s underneath
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: const SizedBox.expand(),
        ),

        // 3. spinner & text
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color.fromARGB(255, 0, 0, 0)),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(
                  color: Color.fromARGB(255, 0, 0, 0),
                  fontSize: 16,
                  shadows: [
                    Shadow(
                      color: Color.fromARGB(136, 94, 94, 94),
                      blurRadius: 4,
                      offset: Offset(1, 1),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

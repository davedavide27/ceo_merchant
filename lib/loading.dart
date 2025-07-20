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
        // Blur effect applied to everything behind
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: const SizedBox.expand(), // Invisible but needed for blur
        ),

        // Only the spinner + optional text
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
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

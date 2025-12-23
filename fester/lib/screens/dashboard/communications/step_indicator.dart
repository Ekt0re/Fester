import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CommunicationsStepIndicator extends StatelessWidget {
  final int currentStep;
  final List<String> steps;

  const CommunicationsStepIndicator({
    super.key,
    required this.currentStep,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(steps.length, (index) {
          final isCompleted = index < currentStep;
          final isCurrent = index == currentStep;

          return Row(
            children: [
              _buildStepCircle(index + 1, isCompleted, isCurrent),
              if (index < steps.length - 1)
                _buildConnector(index < currentStep),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildStepCircle(int number, bool isCompleted, bool isCurrent) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color:
            isCompleted || isCurrent
                ? const Color(0xFFE94560)
                : Colors.grey.withOpacity(0.3),
        shape: BoxShape.circle,
        border: isCurrent ? Border.all(color: Colors.white, width: 2) : null,
      ),
      child: Center(
        child:
            isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Text(
                  number.toString(),
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
      ),
    );
  }

  Widget _buildConnector(bool isCompleted) {
    return Container(
      width: 40,
      height: 2,
      color:
          isCompleted ? const Color(0xFFE94560) : Colors.grey.withOpacity(0.3),
    );
  }
}

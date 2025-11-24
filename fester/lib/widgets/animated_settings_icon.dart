import 'package:flutter/material.dart';

/// Widget per icona settings animata con rotazione on hover
class AnimatedSettingsIcon extends StatefulWidget {
  final VoidCallback onPressed;
  final Color? color;

  const AnimatedSettingsIcon({super.key, required this.onPressed, this.color});

  @override
  State<AnimatedSettingsIcon> createState() => _AnimatedSettingsIconState();
}

class _AnimatedSettingsIconState extends State<AnimatedSettingsIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 30.0 * 3.14159 / 180.0, // 30 gradi in radianti
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHover(bool isHovering) {
    if (isHovering) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: IconButton(
        icon: AnimatedBuilder(
          animation: _rotationAnimation,
          builder: (context, child) {
            return Transform.rotate(
              angle: _rotationAnimation.value,
              child: Icon(Icons.settings, color: widget.color),
            );
          },
        ),
        onPressed: widget.onPressed,
      ),
    );
  }
}

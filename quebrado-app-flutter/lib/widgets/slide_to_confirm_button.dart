import 'package:flutter/material.dart';
import '../theme/colors.dart';

class SlideToConfirmButton extends StatefulWidget {
  final VoidCallback onConfirmed;
  final String label;
  final Color? backgroundColor;
  final Color? handleColor;
  final Color? textColor;
  final bool enabled;

  const SlideToConfirmButton({
    super.key,
    required this.onConfirmed,
    this.label = "Desliza para registrar",
    this.backgroundColor,
    this.handleColor,
    this.textColor,
    this.enabled = true,
  });

  @override
  State<SlideToConfirmButton> createState() => _SlideToConfirmButtonState();
}

class _SlideToConfirmButtonState extends State<SlideToConfirmButton> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  double _dragPosition = 0.0;
  bool _isConfirmed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    )..addListener(() {
        setState(() {
          _dragPosition = _animation.value;
        });
      });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _resetSlider() {
    _animation = Tween<double>(begin: _dragPosition, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _animationController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    const double buttonHeight = 56.0;
    const double handleSize = 46.0;
    const double padding = 5.0;

    final isDarkGrey = !widget.enabled;
    final themeBgColor = isDarkGrey ? Colors.grey[200]! : (widget.backgroundColor ?? AppColors.nestedTabTrackBg);
    final themeHandleColor = isDarkGrey ? Colors.grey[400]! : (widget.handleColor ?? AppColors.primary);
    final themeTextColor = isDarkGrey ? Colors.grey[500]! : (widget.textColor ?? AppColors.primary.withOpacity(0.6));

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxDragDistance = constraints.maxWidth - handleSize - (padding * 2);

        // Calculate opacity for hint text fading out as you drag
        final double textOpacity = widget.enabled
            ? (1.0 - (_dragPosition / maxDragDistance)).clamp(0.0, 1.0)
            : 1.0;

        return Container(
          width: double.infinity,
          height: buttonHeight,
          decoration: BoxDecoration(
            color: themeBgColor,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDarkGrey ? Colors.grey[300]! : AppColors.cardBorderColor,
              width: AppColors.cardBorderWidth,
            ),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Hint Text - positioned to the right of the handle (left: 60) so it's fully readable
              Positioned(
                left: 60,
                right: 20,
                child: Opacity(
                  opacity: textOpacity,
                  child: Center(
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: themeTextColor,
                      ),
                    ),
                  ),
                ),
              ),
              // Sliding Handle
              Positioned(
                left: padding + (widget.enabled ? _dragPosition : 0.0),
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    if (!widget.enabled || _isConfirmed) return;
                    setState(() {
                      _dragPosition += details.delta.dx;
                      if (_dragPosition < 0) _dragPosition = 0;
                      if (_dragPosition > maxDragDistance) _dragPosition = maxDragDistance;
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (!widget.enabled || _isConfirmed) return;
                    if (_dragPosition >= maxDragDistance * 0.85) {
                      // Trigger Confirmation!
                      setState(() {
                        _isConfirmed = true;
                        _dragPosition = maxDragDistance;
                      });
                      widget.onConfirmed();
                      // Reset state after a short delay so if the page doesn't close, it resets
                      Future.delayed(const Duration(milliseconds: 1000), () {
                        if (mounted) {
                          setState(() {
                            _isConfirmed = false;
                            _dragPosition = 0.0;
                          });
                        }
                      });
                    } else {
                      _resetSlider();
                    }
                  },
                  child: Container(
                    width: handleSize,
                    height: handleSize,
                    decoration: BoxDecoration(
                      color: themeHandleColor,
                      shape: BoxShape.circle,
                      boxShadow: widget.enabled
                          ? [
                              BoxShadow(
                                color: themeHandleColor.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      widget.enabled ? Icons.keyboard_double_arrow_right_rounded : Icons.lock_outline_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

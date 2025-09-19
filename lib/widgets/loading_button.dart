import 'package:flutter/material.dart';
import '../utils/constants.dart';

class LoadingButton extends StatelessWidget {
  final String? text;
  final Widget? child;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double height;
  final BorderRadius? borderRadius;
  final bool enabled;

  const LoadingButton({
    super.key,
    this.text,
    this.child,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height = 48,
    this.borderRadius,
    this.enabled = true,
  }) : assert(text != null || child != null, 'Either text or child must be provided');

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading || !enabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? AppColors.primary,
          foregroundColor: textColor ?? Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius ?? BorderRadius.circular(8),
          ),
          elevation: 2,
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : child ?? Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon!, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textColor ?? Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class OutlineLoadingButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color? borderColor;
  final Color? textColor;
  final double? width;
  final double height;
  final BorderRadius? borderRadius;
  final bool enabled;

  const OutlineLoadingButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.borderColor,
    this.textColor,
    this.width,
    this.height = 48,
    this.borderRadius,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = borderColor ?? AppColors.primary;
    
    return SizedBox(
      width: width,
      height: height,
      child: OutlinedButton(
        onPressed: isLoading || !enabled ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: textColor ?? color,
          side: BorderSide(
            color: isLoading || !enabled ? Colors.grey : color,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius ?? BorderRadius.circular(8),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon!, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textColor ?? color,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class TextLoadingButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color? color;
  final double? fontSize;
  final bool enabled;

  const TextLoadingButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.color,
    this.fontSize,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: isLoading || !enabled ? null : onPressed,
      child: isLoading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  color ?? AppColors.primary,
                ),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon!,
                    size: 16,
                    color: color ?? AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  text,
                  style: TextStyle(
                    color: color ?? AppColors.primary,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }
}

class IconLoadingButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? iconColor;
  final double size;
  final String? tooltip;
  final bool enabled;

  const IconLoadingButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.iconColor,
    this.size = 48,
    this.tooltip,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: IconButton(
        onPressed: isLoading || !enabled ? null : onPressed,
        tooltip: tooltip,
        style: IconButton.styleFrom(
          backgroundColor: backgroundColor ?? AppColors.primary,
          foregroundColor: iconColor ?? Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        icon: isLoading
            ? SizedBox(
                width: size * 0.4,
                height: size * 0.4,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    iconColor ?? Colors.white,
                  ),
                ),
              )
            : Icon(
                icon,
                size: size * 0.5,
              ),
      ),
    );
  }
}

class FloatingLoadingButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData icon;
  final Color? backgroundColor;
  final Color? iconColor;
  final String? heroTag;
  final bool mini;
  final String? tooltip;

  const FloatingLoadingButton({
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.icon = Icons.add,
    this.backgroundColor,
    this.iconColor,
    this.heroTag,
    this.mini = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: isLoading ? null : onPressed,
      backgroundColor: backgroundColor ?? AppColors.primary,
      foregroundColor: iconColor ?? Colors.white,
      heroTag: heroTag,
      mini: mini,
      tooltip: tooltip,
      child: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Icon(icon),
    );
  }
}

class SuccessButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool showSuccess;
  final Duration successDuration;
  final IconData? icon;
  final IconData successIcon;
  final Color? backgroundColor;
  final Color successColor;

  const SuccessButton({
    super.key,
    required this.text,
    this.onPressed,
    this.showSuccess = false,
    this.successDuration = const Duration(seconds: 2),
    this.icon,
    this.successIcon = Icons.check,
    this.backgroundColor,
    this.successColor = Colors.green,
  });

  @override
  State<SuccessButton> createState() => _SuccessButtonState();
}

class _SuccessButtonState extends State<SuccessButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _showingSuccess = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(SuccessButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showSuccess && !oldWidget.showSuccess) {
      _showSuccess();
    }
  }

  void _showSuccess() async {
    setState(() {
      _showingSuccess = true;
    });
    _animationController.forward().then((_) {
      _animationController.reverse();
    });
    
    await Future.delayed(widget.successDuration);
    if (mounted) {
      setState(() {
        _showingSuccess = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: ElevatedButton(
              onPressed: _showingSuccess ? null : widget.onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: _showingSuccess
                    ? widget.successColor
                    : (widget.backgroundColor ?? AppColors.primary),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_showingSuccess) ...[
                    Icon(widget.successIcon, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Success!',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ] else ...[
                    if (widget.icon != null) ...[
                      Icon(widget.icon!, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.text,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
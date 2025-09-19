import 'package:flutter/material.dart';

class SafeAreaWrapper extends StatelessWidget {
  final Widget child;
  final bool top;
  final bool bottom;
  final bool left;
  final bool right;
  final double bottomPadding;

  const SafeAreaWrapper({
    Key? key,
    required this.child,
    this.top = true,
    this.bottom = true,
    this.left = true,
    this.right = true,
    this.bottomPadding = 16.0, // Default bottom padding to avoid bottom nav overlap
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      minimum: EdgeInsets.only(bottom: bottomPadding),
      child: child,
    );
  }
}
import 'package:flutter/material.dart';

class MouseEnterListener extends StatefulWidget {
  const MouseEnterListener({super.key, this.child, required this.builder});

  final Widget? child;
  final Widget Function(BuildContext context, bool isMouseInside, Widget? child)
  builder;

  @override
  State<MouseEnterListener> createState() => _MouseEnterListenerState();
}

class _MouseEnterListenerState extends State<MouseEnterListener> {
  bool isMouseInside = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (event) {
        isMouseInside = true;
        setState(() {});
      },
      onExit: (event) {
        isMouseInside = false;
        setState(() {});
      },
      child: widget.builder(context, isMouseInside, widget.child),
    );
  }
}

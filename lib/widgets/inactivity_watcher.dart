import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/auth_notifier.dart';

class InactivityWatcher extends StatefulWidget {
  final Widget child;
  const InactivityWatcher({super.key, required this.child});
  @override
  State<InactivityWatcher> createState() => _InactivityWatcherState();
}

class _InactivityWatcherState extends State<InactivityWatcher> {
  late final AuthNotifier _auth;
  bool _onKey(KeyEvent event) {
    _auth.activity();
    return false;
  }

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthNotifier>();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onHover: (_) => _auth.activity(),
    child: Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _auth.activity(),
      onPointerMove: (_) => _auth.activity(),
      onPointerSignal: (_) => _auth.activity(),
      child: widget.child,
    ),
  );
  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }
}

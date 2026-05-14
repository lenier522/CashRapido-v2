import 'package:flutter/material.dart';

/// A Switch widget with optimistic UI updates for buttery-smooth feel.
///
/// The visual state updates INSTANTLY on tap, then the async [onChanged]
/// callback runs in the background — eliminating the SharedPreferences delay.
class SmoothSwitch extends StatefulWidget {
  final bool value;
  final Future<void> Function(bool)? onChangedAsync;
  final void Function(bool)? onChanged;
  final Color? activeThumbColor;
  final Color? activeTrackColor;

  const SmoothSwitch({
    super.key,
    required this.value,
    this.onChangedAsync,
    this.onChanged,
    this.activeThumbColor,
    this.activeTrackColor,
  }) : assert(
          onChangedAsync != null || onChanged != null,
          'Provide at least one of onChangedAsync or onChanged',
        );

  @override
  State<SmoothSwitch> createState() => _SmoothSwitchState();
}

class _SmoothSwitchState extends State<SmoothSwitch> {
  late bool _localValue;

  @override
  void initState() {
    super.initState();
    _localValue = widget.value;
  }

  @override
  void didUpdateWidget(SmoothSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync with external state changes (e.g., from Provider)
    if (oldWidget.value != widget.value && _localValue != widget.value) {
      _localValue = widget.value;
    }
  }

  void _handleTap(bool newValue) {
    // 1. Update UI immediately — no waiting for async
    setState(() => _localValue = newValue);

    // 2. Run the actual operation in the background
    if (widget.onChangedAsync != null) {
      widget.onChangedAsync!(newValue).catchError((_) {
        // On error, revert the optimistic update
        if (mounted) setState(() => _localValue = !newValue);
      });
    } else {
      widget.onChanged?.call(newValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: _localValue,
      activeThumbColor:
          widget.activeThumbColor ?? Theme.of(context).colorScheme.primary,
      activeTrackColor: widget.activeTrackColor ??
          Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
      onChanged: _handleTap,
    );
  }
}

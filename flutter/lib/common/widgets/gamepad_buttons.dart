import 'package:flutter/material.dart';
import 'package:flutter_hbb/common/shared_state.dart';
import 'package:flutter_hbb/models/model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';

// ── Size / spacing constants ────────────────────────────────────────────────

/// Large primary-action button diameter = 52 dp.
const double _kLargeRadius = 26.0;

/// Small shortcut button diameter = 36 dp.
const double _kSmallRadius = 18.0;

const double _kLargeGap = 8.0;
const double _kSmallGap = 5.0;

/// Vertical gap between the two rows.
const double _kRowGap = 10.0;

// ── Button definitions ──────────────────────────────────────────────────────

class _Btn {
  final String label;
  final String key;
  const _Btn(this.label, this.key);
}

/// Bottom row – four main action buttons (larger).
const List<_Btn> _kLargeRow = [
  _Btn('Spc', 'VK_SPACE'),
  _Btn('Tab', 'VK_TAB'),
  _Btn('C', 'c'),
  _Btn("'", "'"),
];

/// Top row – nine shortcut keys (smaller).
const List<_Btn> _kSmallRow = [
  _Btn('A', 'a'),
  _Btn('S', 's'),
  _Btn('D', 'd'),
  _Btn('F', 'f'),
  _Btn('Q', 'q'),
  _Btn('W', 'w'),
  _Btn('E', 'e'),
  _Btn('R', 'r'),
  _Btn('T', 't'),
];

// ── Public widget ────────────────────────────────────────────────────────────

/// Gamepad-style button panel, placed in the bottom-right corner.
///
/// Visibility is driven by [VirtualJoystickState] — the same menu toggle
/// that controls the left-side joystick.
///
/// Each button uses [Listener] with [HitTestBehavior.opaque] so that touches
/// on the buttons are NOT forwarded to the remote-desktop gesture handler.
class GamepadButtons extends StatelessWidget {
  final FFI ffi;
  final String id;

  const GamepadButtons({Key? key, required this.ffi, required this.id})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!VirtualJoystickState.find(id).value) return const SizedBox.shrink();

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildRow(_kSmallRow, _kSmallRadius, _kSmallGap),
          const SizedBox(height: _kRowGap),
          _buildRow(_kLargeRow, _kLargeRadius, _kLargeGap),
        ],
      );
    });
  }

  Widget _buildRow(List<_Btn> defs, double radius, double gap) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < defs.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          _GamepadButton(def: defs[i], radius: radius, ffi: ffi),
        ],
      ],
    );
  }
}

// ── Single button ─────────────────────────────────────────────────────────

class _GamepadButton extends StatefulWidget {
  final _Btn def;
  final double radius;
  final FFI ffi;

  const _GamepadButton({
    Key? key,
    required this.def,
    required this.radius,
    required this.ffi,
  }) : super(key: key);

  @override
  State<_GamepadButton> createState() => _GamepadButtonState();
}

class _GamepadButtonState extends State<_GamepadButton> {
  bool _pressed = false;

  void _send(bool down) {
    bind.sessionInputKey(
      sessionId: widget.ffi.sessionId,
      name: widget.def.key,
      down: down,
      press: false,
      alt: false,
      ctrl: false,
      shift: false,
      command: false,
    );
  }

  void _onDown() {
    if (_pressed) return;
    _send(true);
    setState(() => _pressed = true);
  }

  void _onUp() {
    if (!_pressed) return;
    _send(false);
    setState(() => _pressed = false);
  }

  @override
  void dispose() {
    // Release the key if the widget is removed while the button is held.
    if (_pressed) _send(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.radius * 2;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _onDown(),
      onPointerUp: (_) => _onUp(),
      onPointerCancel: (_) => _onUp(),
      child: Container(
        width: d,
        height: d,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _pressed
              ? Colors.white.withOpacity(0.45)
              : Colors.black.withOpacity(0.35),
          border: Border.all(
            color: Colors.white.withOpacity(0.55),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              widget.def.label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.90),
                fontSize: widget.radius * 0.78,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

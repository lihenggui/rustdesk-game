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

/// Alt-lock indicator button size (diameter).
const double _kAltLockSize = 22.0;

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

/// Top row – nine shortcut keys (smaller, affected by Alt lock).
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
/// A small Alt-lock toggle sits at the top-right corner of the small-buttons
/// row. When active, every small button sends Alt+[key] instead of [key].
class GamepadButtons extends StatefulWidget {
  final FFI ffi;
  final String id;

  const GamepadButtons({Key? key, required this.ffi, required this.id})
      : super(key: key);

  @override
  State<GamepadButtons> createState() => _GamepadButtonsState();
}

class _GamepadButtonsState extends State<GamepadButtons> {
  /// Whether the Alt modifier is locked on for the small-button row.
  bool _altLock = false;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!VirtualJoystickState.find(widget.id).value) {
        return const SizedBox.shrink();
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Small-button row with the Alt-lock badge in the top-right corner.
          Stack(
            clipBehavior: Clip.none,
            children: [
              _buildRow(_kSmallRow, _kSmallRadius, _kSmallGap, alt: _altLock),
              Positioned(
                top: -10,
                right: -10,
                child: _AltLockButton(
                  active: _altLock,
                  onTap: () => setState(() => _altLock = !_altLock),
                ),
              ),
            ],
          ),
          const SizedBox(height: _kRowGap),
          _buildRow(_kLargeRow, _kLargeRadius, _kLargeGap, alt: false),
        ],
      );
    });
  }

  Widget _buildRow(
    List<_Btn> defs,
    double radius,
    double gap, {
    required bool alt,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < defs.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          _GamepadButton(
            def: defs[i],
            radius: radius,
            ffi: widget.ffi,
            alt: alt,
          ),
        ],
      ],
    );
  }
}

// ── Alt-lock toggle badge ────────────────────────────────────────────────────

class _AltLockButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _AltLockButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: _kAltLockSize,
        height: _kAltLockSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active
              ? Colors.amber.withOpacity(0.85)
              : Colors.black.withOpacity(0.55),
          border: Border.all(
            color: active
                ? Colors.amber.withOpacity(0.95)
                : Colors.white.withOpacity(0.55),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(3.0),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Alt',
              style: TextStyle(
                color: active
                    ? Colors.black.withOpacity(0.85)
                    : Colors.white.withOpacity(0.80),
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

// ── Single button ─────────────────────────────────────────────────────────

class _GamepadButton extends StatefulWidget {
  final _Btn def;
  final double radius;
  final FFI ffi;

  /// Whether to send the Alt modifier with this button press.
  /// Captured at pointer-down so that down/up always use the same modifier,
  /// even if the Alt lock is toggled mid-press.
  final bool alt;

  const _GamepadButton({
    Key? key,
    required this.def,
    required this.radius,
    required this.ffi,
    required this.alt,
  }) : super(key: key);

  @override
  State<_GamepadButton> createState() => _GamepadButtonState();
}

class _GamepadButtonState extends State<_GamepadButton> {
  bool _pressed = false;

  /// Alt value captured at the moment the button was pressed.
  /// Ensures key-up carries the same modifier as key-down.
  bool _altAtPress = false;

  void _send(bool down, {required bool alt}) {
    bind.sessionInputKey(
      sessionId: widget.ffi.sessionId,
      name: widget.def.key,
      down: down,
      press: false,
      alt: alt,
      ctrl: false,
      shift: false,
      command: false,
    );
  }

  void _onDown() {
    if (_pressed) return;
    _altAtPress = widget.alt; // snapshot modifier state at press time
    _send(true, alt: _altAtPress);
    setState(() => _pressed = true);
  }

  void _onUp() {
    if (!_pressed) return;
    _send(false, alt: _altAtPress);
    setState(() => _pressed = false);
  }

  @override
  void dispose() {
    if (_pressed) _send(false, alt: _altAtPress);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.radius * 2;
    // Tint the button amber when Alt lock is active to give visual feedback.
    final borderColor = widget.alt
        ? Colors.amber.withOpacity(0.80)
        : Colors.white.withOpacity(0.55);

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
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              widget.def.label,
              style: TextStyle(
                color: widget.alt
                    ? Colors.amber.withOpacity(0.95)
                    : Colors.white.withOpacity(0.90),
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

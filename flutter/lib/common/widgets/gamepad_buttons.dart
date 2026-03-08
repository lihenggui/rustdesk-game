import 'package:flutter/material.dart';
import 'package:flutter_hbb/common/shared_state.dart';
import 'package:flutter_hbb/models/model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';

// ── Size / spacing constants ────────────────────────────────────────────────

/// Large primary-action button – max diameter 52 dp.
const double _kLargeRadius = 26.0;

/// Small shortcut button – max diameter 36 dp.
const double _kSmallRadius = 18.0;

const double _kLargeGap = 8.0;
const double _kSmallGap = 5.0;
const double _kRowGap = 10.0;

/// Alt-lock badge size – kept small so it fits beside the number row.
const double _kAltLockSize = 16.0;

/// Portrait expand/collapse toggle diameter.
const double _kToggleSize = 34.0;

/// Left-side reserved width in portrait:
/// joystick left-margin(16) + joystick width(144) + gap(16) = 176 dp.
const double _kJoystickReserved = 176.0;

// ── Button definitions ──────────────────────────────────────────────────────

class _Btn {
  final String label;
  final int hid; // USB HID usage code
  const _Btn(this.label, this.hid);
}

// USB HID usage codes (standard HID Usage Table for Keyboard/Keypad page 0x07)
const int _hidAltLeft = 0xE2;

/// Bottom row – five main action buttons (larger).
const List<_Btn> _kLargeRow = [
  _Btn('N', 0x11),
  _Btn("'", 0x34),
  _Btn('C', 0x06),
  _Btn('Tab', 0x2B),
  _Btn('Spc', 0x2C),
];

/// Top number row – 6-0 on the main keyboard (not numpad, not Alt-affected).
const List<_Btn> _kNumberRow = [
  _Btn('6', 0x23),
  _Btn('7', 0x24),
  _Btn('8', 0x25),
  _Btn('9', 0x26),
  _Btn('0', 0x27),
];

/// Second row – QWERTY keys (affected by Alt lock).
const List<_Btn> _kQwertyRow = [
  _Btn('Q', 0x14),
  _Btn('W', 0x1A),
  _Btn('E', 0x08),
  _Btn('R', 0x15),
  _Btn('T', 0x17),
];

/// Middle shortcut row – ASDFG keys (affected by Alt lock) + Enter.
const List<_Btn> _kAsdfRow = [
  _Btn('A', 0x04),
  _Btn('S', 0x16),
  _Btn('D', 0x07),
  _Btn('F', 0x09),
  _Btn('G', 0x0A),
  _Btn('↵', 0x28),
];

// ── Public widget ────────────────────────────────────────────────────────────

/// Gamepad-style button panel for the bottom-right corner.
///
/// **Landscape**: always visible, full-size buttons.
/// **Portrait**: collapsed by default (shows only a chevron toggle);
///   tap to expand. When expanded, button sizes are calculated dynamically
///   so the panel fits in the space to the right of the joystick.
class GamepadButtons extends StatefulWidget {
  final FFI ffi;
  final String id;

  const GamepadButtons({Key? key, required this.ffi, required this.id})
      : super(key: key);

  @override
  State<GamepadButtons> createState() => _GamepadButtonsState();
}

class _GamepadButtonsState extends State<GamepadButtons> {
  bool _altLock = false;

  /// Portrait-only: whether the button panel is currently expanded.
  /// Persists across gamepad-mode on/off toggles.
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!VirtualJoystickState.find(widget.id).value) {
        return const SizedBox.shrink();
      }

      final isPortrait =
          MediaQuery.of(context).orientation == Orientation.portrait;

      // ── Landscape: full panel, fixed sizes ──────────────────────────────
      if (!isPortrait) {
        return _buildPanel(
          smallRadius: _kSmallRadius,
          smallGap: _kSmallGap,
          largeRadius: _kLargeRadius,
          largeGap: _kLargeGap,
        );
      }

      // ── Portrait: chevron toggle + conditionally expanded panel ─────────
      //
      // Available width = screenWidth minus the space the joystick occupies
      // on the left (left:16 + width:144 + gap:16 = 176 dp).
      final screenWidth = MediaQuery.of(context).size.width;
      final available =
          (screenWidth - _kJoystickReserved).clamp(100.0, double.infinity);

      // Derive button radii so all rows fit inside `available`.
      // Take the tightest constraint among all small-button rows.
      const smallGap = 3.0;
      const largeGap = 5.0;
      const altPadding = 4.0 + _kAltLockSize; // gap + badge
      final rNumber =
          (available - (_kNumberRow.length - 1) * smallGap - altPadding) /
              (_kNumberRow.length * 2);
      final rAsdf =
          (available - (_kAsdfRow.length - 1) * smallGap) /
              (_kAsdfRow.length * 2);
      final smallRadius = (rNumber < rAsdf ? rNumber : rAsdf)
          .clamp(8.0, _kSmallRadius);
      final largeRadius =
          ((available - (_kLargeRow.length - 1) * largeGap) /
                  (_kLargeRow.length * 2))
              .clamp(12.0, _kLargeRadius);

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_expanded) ...[
            _buildPanel(
              smallRadius: smallRadius,
              smallGap: smallGap,
              largeRadius: largeRadius,
              largeGap: largeGap,
            ),
            const SizedBox(height: 6),
          ],
          _buildPortraitToggle(),
        ],
      );
    });
  }

  // ── Button panel (two rows + Alt lock badge) ──────────────────────────────

  Widget _buildPanel({
    required double smallRadius,
    required double smallGap,
    required double largeRadius,
    required double largeGap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Number row with Alt badge tucked to the right – no overlap possible.
        // Alt does NOT affect the number row.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRow(_kNumberRow, smallRadius, smallGap, alt: false),
            const SizedBox(width: 4),
            _AltLockButton(
              active: _altLock,
              onTap: () => setState(() => _altLock = !_altLock),
            ),
          ],
        ),
        const SizedBox(height: _kRowGap / 2),
        _buildRow(_kQwertyRow, smallRadius, smallGap, alt: _altLock),
        const SizedBox(height: _kRowGap / 2),
        _buildRow(_kAsdfRow, smallRadius, smallGap, alt: _altLock),
        const SizedBox(height: _kRowGap),
        _buildRow(_kLargeRow, largeRadius, largeGap, alt: false),
      ],
    );
  }

  // ── Portrait toggle (chevron) ─────────────────────────────────────────────

  Widget _buildPortraitToggle() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        width: _kToggleSize,
        height: _kToggleSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _expanded
              ? Colors.white.withOpacity(0.20)
              : Colors.black.withOpacity(0.45),
          border: Border.all(
            color: Colors.white.withOpacity(0.55),
            width: 1.5,
          ),
        ),
        child: Icon(
          // ‹ collapse (panel is open), › expand (panel is hidden)
          _expanded ? Icons.chevron_right : Icons.chevron_left,
          color: Colors.white.withOpacity(0.85),
          size: 20,
        ),
      ),
    );
  }

  // ── Row builder ───────────────────────────────────────────────────────────

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

// ── Alt-lock toggle badge ─────────────────────────────────────────────────

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

  /// Snapshot of the alt modifier at the moment the button was pressed.
  /// Guarantees key-up always carries the same modifier as its key-down,
  /// even if the Alt lock is toggled mid-press.
  bool _altAtPress = false;

  void _sendHid(int hid, bool down) {
    bind.sessionHandleFlutterKeyEvent(
      sessionId: widget.ffi.sessionId,
      character: '',
      usbHid: hid,
      lockModes: 0,
      downOrUp: down,
    );
  }

  void _send(bool down, {required bool alt}) {
    if (alt && down) {
      _sendHid(_hidAltLeft, true);
    }
    _sendHid(widget.def.hid, down);
    if (alt && !down) {
      _sendHid(_hidAltLeft, false);
    }
  }

  void _onDown() {
    if (_pressed) return;
    _altAtPress = widget.alt;
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

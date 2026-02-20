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
const double _kAltLockSize = 22.0;

/// Portrait expand/collapse toggle diameter.
const double _kToggleSize = 34.0;

/// Left-side reserved width in portrait:
/// joystick left-margin(16) + joystick width(144) + gap(16) = 176 dp.
const double _kJoystickReserved = 176.0;

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

/// Top row – nine shortcut keys (affected by Alt lock).
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

      // Derive button radii so both rows fit exactly inside `available`.
      const smallGap = 3.0;
      const largeGap = 5.0;
      final smallRadius =
          ((available - (_kSmallRow.length - 1) * smallGap) /
                  (_kSmallRow.length * 2))
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
        Stack(
          clipBehavior: Clip.none,
          children: [
            _buildRow(_kSmallRow, smallRadius, smallGap, alt: _altLock),
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
              ? Colors.white.withValues(alpha: 0.20)
              : Colors.black.withValues(alpha: 0.45),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.55),
            width: 1.5,
          ),
        ),
        child: Icon(
          // ‹ collapse (panel is open), › expand (panel is hidden)
          _expanded ? Icons.chevron_right : Icons.chevron_left,
          color: Colors.white.withValues(alpha:0.85),
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
              ? Colors.amber.withValues(alpha:0.85)
              : Colors.black.withValues(alpha:0.55),
          border: Border.all(
            color: active
                ? Colors.amber.withValues(alpha:0.95)
                : Colors.white.withValues(alpha:0.55),
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
                    ? Colors.black.withValues(alpha:0.85)
                    : Colors.white.withValues(alpha:0.80),
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
        ? Colors.amber.withValues(alpha:0.80)
        : Colors.white.withValues(alpha:0.55);

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
              ? Colors.white.withValues(alpha:0.45)
              : Colors.black.withValues(alpha:0.35),
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
                    ? Colors.amber.withValues(alpha:0.95)
                    : Colors.white.withValues(alpha:0.90),
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

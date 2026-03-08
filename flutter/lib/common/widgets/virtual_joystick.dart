import 'package:flutter/material.dart';
import 'package:flutter_hbb/common/shared_state.dart';
import 'package:flutter_hbb/models/model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';

// Visual constants
const double _kBaseRadius = 64.0;
const double _kStickRadius = 24.0;
const double _kPad = 8.0;
const double _kJoystickSize = (_kBaseRadius + _kPad) * 2;

// Dead zone: stick must move past 28% of base radius to trigger a key
const double _kDeadZone = 0.28;

// Arrow indicator distances from center
const double _kArrowOffset = 46.0;
const double _kArrowHalfWidth = 8.0;
const double _kArrowHeight = 11.0;

/// Semi-transparent gamepad joystick overlay for the bottom-left corner.
///
/// Captures all touch/pan events within its bounds (does NOT forward them to
/// the remote desktop) and sends VK_UP / VK_DOWN / VK_LEFT / VK_RIGHT
/// key-down / key-up events to the remote machine as the stick is moved.
///
/// Named [GameJoystick] to avoid collision with the mouse-cursor
/// [VirtualJoystick] widget in `floating_mouse_widgets.dart`.
class GameJoystick extends StatefulWidget {
  final FFI ffi;
  final String id;

  const GameJoystick({Key? key, required this.ffi, required this.id})
      : super(key: key);

  @override
  State<GameJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<GameJoystick> {
  // Current stick offset from the joystick centre (clamped to base radius)
  Offset _stick = Offset.zero;

  // Which directional keys are currently held down
  bool _upPressed = false;
  bool _downPressed = false;
  bool _leftPressed = false;
  bool _rightPressed = false;

  // Centre of the joystick within the fixed-size SizedBox
  static const double _cx = _kBaseRadius + _kPad;
  static const double _cy = _kBaseRadius + _kPad;

  // USB HID usage codes for arrow keys
  static const int _hidUp = 0x52;
  static const int _hidDown = 0x51;
  static const int _hidLeft = 0x50;
  static const int _hidRight = 0x4F;

  void _sendHid(int hid, bool down) {
    bind.sessionHandleFlutterKeyEvent(
      sessionId: widget.ffi.sessionId,
      character: '',
      usbHid: hid,
      lockModes: 0,
      downOrUp: down,
    );
  }

  /// Compare desired key states vs current and emit only the changed events.
  void _updateDirections(Offset offset) {
    final dead = _kBaseRadius * _kDeadZone;
    final newUp = offset.dy < -dead;
    final newDown = offset.dy > dead;
    final newLeft = offset.dx < -dead;
    final newRight = offset.dx > dead;

    if (newUp != _upPressed) {
      _sendHid(_hidUp, newUp);
      _upPressed = newUp;
    }
    if (newDown != _downPressed) {
      _sendHid(_hidDown, newDown);
      _downPressed = newDown;
    }
    if (newLeft != _leftPressed) {
      _sendHid(_hidLeft, newLeft);
      _leftPressed = newLeft;
    }
    if (newRight != _rightPressed) {
      _sendHid(_hidRight, newRight);
      _rightPressed = newRight;
    }
  }

  void _releaseAll() {
    if (_upPressed) {
      _sendHid(_hidUp, false);
      _upPressed = false;
    }
    if (_downPressed) {
      _sendHid(_hidDown, false);
      _downPressed = false;
    }
    if (_leftPressed) {
      _sendHid(_hidLeft, false);
      _leftPressed = false;
    }
    if (_rightPressed) {
      _sendHid(_hidRight, false);
      _rightPressed = false;
    }
    if (mounted) setState(() => _stick = Offset.zero);
  }

  @override
  void dispose() {
    _releaseAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!VirtualJoystickState.find(widget.id).value) {
        return const SizedBox.shrink();
      }
      return GestureDetector(
        // opaque: absorbs all hits inside this widget's box so touches are
        // NOT forwarded to the RawTouchGestureDetectorRegion sibling below.
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) {
          // Compute offset of the touch from the joystick centre
          final rawOffset =
              d.localPosition - const Offset(_cx, _cy);
          final dist = rawOffset.distance;
          final maxDist = _kBaseRadius - _kStickRadius;
          final clamped =
              dist > maxDist ? rawOffset * (maxDist / dist) : rawOffset;
          setState(() => _stick = clamped);
          _updateDirections(clamped);
        },
        onPanEnd: (_) => _releaseAll(),
        onPanCancel: () => _releaseAll(),
        child: SizedBox(
          width: _kJoystickSize,
          height: _kJoystickSize,
          child: CustomPaint(
            painter: _JoystickPainter(stickOffset: _stick),
          ),
        ),
      );
    });
  }
}

// ─── Painter ────────────────────────────────────────────────────────────────

class _JoystickPainter extends CustomPainter {
  final Offset stickOffset;

  _JoystickPainter({required this.stickOffset});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);

    // Base circle – filled + ring
    canvas.drawCircle(
      c,
      _kBaseRadius,
      Paint()
        ..color = Colors.black.withOpacity(0.30)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      c,
      _kBaseRadius,
      Paint()
        ..color = Colors.white.withOpacity(0.50)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Direction arrows
    _drawArrows(canvas, c);

    // Movable stick
    final sc = c + stickOffset;
    canvas.drawCircle(
      sc,
      _kStickRadius,
      Paint()
        ..color = Colors.white.withOpacity(0.60)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      sc,
      _kStickRadius,
      Paint()
        ..color = Colors.white.withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawArrows(Canvas canvas, Offset c) {
    final p = Paint()
      ..color = Colors.white.withOpacity(0.45)
      ..style = PaintingStyle.fill;
    const ao = _kArrowOffset;
    const aw = _kArrowHalfWidth;
    const ah = _kArrowHeight;

    // Up ▲
    canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - ao)
          ..lineTo(c.dx - aw, c.dy - ao + ah)
          ..lineTo(c.dx + aw, c.dy - ao + ah)
          ..close(),
        p);
    // Down ▼
    canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy + ao)
          ..lineTo(c.dx - aw, c.dy + ao - ah)
          ..lineTo(c.dx + aw, c.dy + ao - ah)
          ..close(),
        p);
    // Left ◀
    canvas.drawPath(
        Path()
          ..moveTo(c.dx - ao, c.dy)
          ..lineTo(c.dx - ao + ah, c.dy - aw)
          ..lineTo(c.dx - ao + ah, c.dy + aw)
          ..close(),
        p);
    // Right ▶
    canvas.drawPath(
        Path()
          ..moveTo(c.dx + ao, c.dy)
          ..lineTo(c.dx + ao - ah, c.dy - aw)
          ..lineTo(c.dx + ao - ah, c.dy + aw)
          ..close(),
        p);
  }

  @override
  bool shouldRepaint(_JoystickPainter old) => stickOffset != old.stickOffset;
}

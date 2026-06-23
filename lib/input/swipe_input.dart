import 'package:flutter/widgets.dart';

import '../game/direction.dart';

/// Translates pan gestures over the maze into buffered [Direction] events
/// (control-scheme §2). Swipe is the primary scheme; an optional D-pad feeds the
/// same callback.
///
/// Phase 1 (Skeleton): wraps a child in a [GestureDetector] and emits a
/// direction on pan end. Early-commit, the 16px / 1.3× thresholds, debounce, and
/// the 0.5s buffer window are Phase 2 TODOs.
class SwipeInput extends StatelessWidget {
  const SwipeInput({
    super.key,
    required this.child,
    required this.onDirection,
  });

  final Widget child;
  final ValueChanged<Direction> onDirection;

  /// Minimum travel before a swipe counts (control-scheme §6: 16 logical px).
  static const double minTravel = 16;

  /// Axis must dominate by this factor to commit (control-scheme §2: 1.3×).
  static const double axisDominance = 1.3;

  @override
  Widget build(BuildContext context) {
    Offset start = Offset.zero;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (d) => start = d.localPosition,
      onPanEnd: (d) {
        // TODO(Phase 2): early-commit mid-pan + debounce; this end-of-pan
        // version is enough to drive the skeleton.
      },
      onPanUpdate: (d) {
        final delta = d.localPosition - start;
        if (delta.distance < minTravel) return;
        final dir = _resolve(delta);
        if (dir != null) {
          onDirection(dir);
          start = d.localPosition; // debounce: one direction per gesture-ish
        }
      },
      child: child,
    );
  }

  Direction? _resolve(Offset delta) {
    final adx = delta.dx.abs();
    final ady = delta.dy.abs();
    if (adx >= ady * axisDominance) {
      return delta.dx > 0 ? Direction.right : Direction.left;
    }
    if (ady >= adx * axisDominance) {
      return delta.dy > 0 ? Direction.down : Direction.up;
    }
    return null; // too diagonal — ignore (control-scheme §2)
  }
}

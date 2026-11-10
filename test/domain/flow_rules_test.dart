import 'package:flutter_test/flutter_test.dart';
import 'package:flow/domain/use_cases/flow_rules.dart';

import '../helpers/test_doubles.dart';

void main() {
  final level = threeByThreeLevel(1);

  group('FlowRules.isFlowConnected', () {
    test('true when the path joins both endpoints in either direction', () {
      expect(FlowRules.isFlowConnected(1, [0, 1, 2], level), isTrue);
      expect(FlowRules.isFlowConnected(1, [2, 1, 0], level), isTrue);
    });

    test('false for partial paths, wrong colours or single cells', () {
      expect(FlowRules.isFlowConnected(1, [0, 1], level), isFalse);
      expect(FlowRules.isFlowConnected(1, [0], level), isFalse);
      expect(FlowRules.isFlowConnected(2, [0, 1, 2], level), isFalse);
      expect(FlowRules.isFlowConnected(99, [0, 1, 2], level), isFalse);
    });
  });

  group('FlowRules board metrics', () {
    test('counts connected flows and occupied cells', () {
      final paths = {
        1: [0, 1, 2],
        2: [3, 4],
      };
      expect(FlowRules.connectedFlowsCount(paths, level), 1);
      expect(FlowRules.occupiedCellsCount(paths), 5);
      expect(FlowRules.pipePercentage(paths, level), 56); // 5/9 rounded
    });

    test('pipe percentage is 0 for an empty board and 100 when full', () {
      expect(FlowRules.pipePercentage(const {}, level), 0);
      expect(FlowRules.pipePercentage(level.solution, level), 100);
    });
  });

  group('FlowRules.isComplete', () {
    test('true only when every flow is connected and the grid is full', () {
      expect(FlowRules.isComplete(level.solution, level), isTrue);
    });

    test('false when a flow is missing', () {
      final paths = Map.of(level.solution)..remove(3);
      expect(FlowRules.isComplete(paths, level), isFalse);
    });

    test('false when all flows connect but cells stay empty', () {
      final sparse = threeByThreeLevel(1).copyWith(
        dots: const {
          1: [0, 1],
        },
      );
      expect(
        FlowRules.isComplete(const {
          1: [0, 1],
        }, sparse),
        isFalse,
      );
    });
  });

  group('FlowRules.canStep', () {
    test('allows orthogonal neighbours', () {
      expect(FlowRules.canStep(4, 1, 2, level), isTrue);
      expect(FlowRules.canStep(4, 3, 2, level), isTrue);
      expect(FlowRules.canStep(4, 5, 2, level), isTrue);
      expect(FlowRules.canStep(4, 7, 2, level), isTrue);
    });

    test('rejects diagonals, jumps and out-of-bounds cells', () {
      expect(FlowRules.canStep(4, 0, 2, level), isFalse);
      expect(FlowRules.canStep(0, 2, 1, level), isFalse);
      expect(FlowRules.canStep(0, -1, 1, level), isFalse);
      expect(FlowRules.canStep(8, 9, 3, level), isFalse);
    });

    test('rejects wrapping from one row end to the next row start', () {
      // Cells 2 and 3 are consecutive indices but not neighbours.
      expect(FlowRules.canStep(2, 3, 1, level), isFalse);
    });

    test('rejects stepping onto a different colour\'s dot', () {
      expect(FlowRules.canStep(1, 4, 1, level), isTrue);
      expect(FlowRules.canStep(4, 3, 1, level), isFalse); // dot of colour 2
      expect(FlowRules.canStep(1, 2, 1, level), isTrue); // own dot
    });
  });
}

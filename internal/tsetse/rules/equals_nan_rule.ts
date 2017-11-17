/**
 * @fileoverview Bans `== NaN` in TypeScript code, since it is always false for
 * any value.
 */

import * as tsutils from 'tsutils';
import * as ts from 'typescript';

import {Checker} from '../checker';
import {AbstractRule} from '../rule';

const FAILURE_STRING = 'x == NaN always returns false; use isNaN(x) instead';

export class Rule extends AbstractRule {
  readonly ruleName = 'equals-nan';
  readonly code = 21222;

  register(checker: Checker) {
    checker.on(
        ts.SyntaxKind.BinaryExpression, checkBinaryExpression, this.code);
  }
}

function checkBinaryExpression(checker: Checker, node: ts.BinaryExpression) {
  if ((node.operatorToken.kind === ts.SyntaxKind.EqualsEqualsToken ||
       node.operatorToken.kind === ts.SyntaxKind.EqualsEqualsEqualsToken) &&
      (node.left.getText() === 'NaN' || node.right.getText() === 'NaN')) {
    checker.addFailureAtNode(node, FAILURE_STRING);
  }
}

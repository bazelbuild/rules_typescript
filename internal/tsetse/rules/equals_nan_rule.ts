/**
 * @fileoverview Bans `== NaN`, `=== NaN`, `!= NaN`, and `!== NaN` in TypeScript
 * code, since no value (including NaN) is equal to NaN.
 */

import * as ts from 'typescript';

import {Checker} from '../checker';
import {ErrorCode} from '../error_code';
import {AbstractRule} from '../rule';

export class Rule extends AbstractRule {
  readonly ruleName = 'equals-nan';
  readonly code = ErrorCode.EQUALS_NAN;

  register(checker: Checker) {
    checker.on(
        ts.SyntaxKind.BinaryExpression, checkBinaryExpression, this.code);
  }
}

function checkBinaryExpression(checker: Checker, node: ts.BinaryExpression) {
  const isLeftNaN = ts.isIdentifier(node.left) && node.left.text === 'NaN';
  const isRightNaN = ts.isIdentifier(node.right) && node.right.text === 'NaN';
  if (!isLeftNaN && !isRightNaN) {
    return;
  }

  switch (node.operatorToken.kind) {
    case ts.SyntaxKind.EqualsEqualsToken:
    case ts.SyntaxKind.EqualsEqualsEqualsToken:
      checker.addFailureAtNode(
        node,
        `x ==/=== NaN is always false; use isNaN(x) instead`,
      );
      break;
    case ts.SyntaxKind.ExclamationEqualsToken:
    case ts.SyntaxKind.ExclamationEqualsEqualsToken:
      checker.addFailureAtNode(
        node,
        `x !=/!== NaN is always true; use !isNaN(x) instead`,
      );
      break;
  }
}

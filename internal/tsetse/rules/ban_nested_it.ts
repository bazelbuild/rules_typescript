/**
 * @fileoverview Bans nested 'it' methods.
 * As these cause falsy positive in unit tests.
 */

import * as ts from 'typescript';

import { Checker } from '../checker';
import { ErrorCode } from '../error_code';
import { AbstractRule } from '../rule';

const FAILURE_STRING = `Nested Jasmine 'it' are not allowed. Did you mean to use 'describe'?`;

export class Rule extends AbstractRule {
	readonly ruleName = 'ban_nested_it';
	readonly code = ErrorCode.BAN_NESTED_IT;

	register(checker: Checker) {
		checker.on(ts.SyntaxKind.CallExpression, checkCallExpression, this.code);
	}
}

function checkCallExpression(checker: Checker, node: ts.CallExpression) {
	if (isJasmineIt(checker, node) && hasNestedItExpression(checker, node)) {
		checker.addFailureAtNode(node, FAILURE_STRING);
	}
}

function isJasmineIt(checker: Checker, node: ts.CallExpression): boolean {
	if (node.expression.getText() !== 'it') {
		return false;
	}

	// get the `jasmine` module file path
	const jasmineModule = checker.typeChecker
		.getAmbientModules()
		.find(x => x.name.replace(/"/g, '') === 'jasmine');

	if (!jasmineModule) {
		return false;
	}
	const declarations = jasmineModule.getDeclarations();
	let jasmineModulePath = '';
	if (declarations && declarations.length) {
		jasmineModulePath = declarations[0].getSourceFile().fileName;
	}

	const signature = checker.typeChecker.getResolvedSignature(node);
	const file = signature.getDeclaration().getSourceFile();

	// math the file path of the `it` with that of `jasmine`
	return jasmineModulePath === file.fileName;
}

function hasNestedItExpression(checker: Checker, node: ts.Node): boolean {
	let canProcessNode = false;
	switch (node.kind) {
		case ts.SyntaxKind.Block:
		case ts.SyntaxKind.ArrowFunction:
		case ts.SyntaxKind.FunctionExpression:
		case ts.SyntaxKind.SyntaxList:
		case ts.SyntaxKind.ExpressionStatement:
		case ts.SyntaxKind.CallExpression:
			canProcessNode = true
			break;
	}

	if (!canProcessNode) {
		return false;
	}

	const result = ts.forEachChild(node, (node => {
		if (ts.isCallExpression(node) && isJasmineIt(checker, node)) {
			return true;
		}

		return hasNestedItExpression(checker, node);
	}));

	return !!result;
}
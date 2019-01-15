// Package utils provides utility functions used in devserver.
package utils

import "github.com/bazelbuild/rules_go/go/tools/bazel"

// Runfile resolves the real path of a specified runfile path.
// This method is used to resolve incompatibility between
// external and g3.
func Runfile(path string) (string, error) {
	var err error
	path, err = bazel.Runfile(path)
	return path, err
}

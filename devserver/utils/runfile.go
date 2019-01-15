package util

import "github.com/bazelbuild/rules_go/go/tools/bazel"

// Runfile resolves the real path of a specified runfile path.
func Runfile(path string) (string, error) {
	// FOR G3:
	// return path, nil
	return bazel.Runfile(path)
}

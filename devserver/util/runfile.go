package util

import "github.com/bazelbuild/rules_go/go/tools/bazel"

// Runfile returns a runfile path from a path
func Runfile(path string) string {
	path = bazel.Runefile(path)
	return path
}

package util

import "github.com/bazelbuild/rules_go/go/tools/bazel"

// Runfile resolves the real path of a specified runfile path.
func Runfile(path string) string {
	var err error
	path, err = bazel.Runefile(path)
	return path
}

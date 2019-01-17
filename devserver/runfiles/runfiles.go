// Runfiles package that provides utility helpers for resolving Bazel runfiles within Go. This is an abstraction
// needed for G3 because we don't want to sync the "rules_go" runfile helpers yet.
package runfiles

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/bazelbuild/rules_go/go/tools/bazel"
)

var isG3 = false

func Runfile(manifestPath string) (string, error) {
	if isG3 {
		runfilesDir := os.Getenv("RUNFILES")

		if len(runfilesDir) == 0 {
			return "", fmt.Errorf("could not find bazel runfiles directory. \"RUNFILES\" environment " +
				"variable is not set")
		}

		return filepath.Join(runfilesDir, manifestPath), nil
	}

	return bazel.Runfile(manifestPath)
}

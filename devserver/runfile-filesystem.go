// Contains the RunfileFileSystem implementation.
package main

import (
	"io/ioutil"
	"os"
	"time"

	"github.com/bazelbuild/rules_typescript/util"
)

// RunfileFileSystem implements FileSystem type from concatjs.
type RunfileFileSystem struct{}

// StatMtime gets the filestamp for the last file modification.
func (fs *RunfileFileSystem) StatMtime(filename string) (time.Time, error) {
	s, err := os.Stat(filename)
	if err != nil {
		return time.Time{}, err
	}
	return s.ModTime(), nil
}

// ReadFile reads a file given its file name
func (fs *RunfileFileSystem) ReadFile(filename string) ([]byte, error) {
	return ioutil.ReadFile(filename)
}

// ResolvePath resolves the path for given file relative to a root path
func (fs *RunfileFileSystem) ResolvePath(root string, file string) (string, error) {
	return util.Runfile(file)
}

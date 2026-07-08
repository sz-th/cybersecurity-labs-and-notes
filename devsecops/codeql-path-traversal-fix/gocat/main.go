package main

import (
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

var (
	errInvalidPath = errors.New("invalid path")
	errOutsideBase = errors.New("path outside base directory")
)

func safePath(baseDir, name string) (string, error) {
	if name == "" {
		return "", errInvalidPath
	}

	clean := filepath.Clean(name)
	if filepath.IsAbs(clean) || strings.HasPrefix(clean, "..") {
		return "", errInvalidPath
	}

	baseAbs, err := filepath.Abs(baseDir)
	if err != nil {
		return "", err
	}

	full := filepath.Join(baseAbs, clean)
	fullAbs, err := filepath.Abs(full)
	if err != nil {
		return "", err
	}

	rel, err := filepath.Rel(baseAbs, fullAbs)
	if err != nil {
		return "", err
	}
	if rel == ".." || strings.HasPrefix(rel, ".."+string(os.PathSeparator)) {
		return "", errOutsideBase
	}

	return fullAbs, nil
}

func catFile(baseDir, name string, w io.Writer) error {
	target, err := safePath(baseDir, name)
	if err != nil {
		return err
	}

	data, err := os.ReadFile(target)
	if err != nil {
		return err
	}

	_, err = w.Write(data)
	return err
}

func main() {
	base := flag.String("base", ".", "base directory for reads")
	flag.Parse()

	if flag.NArg() != 1 {
		fmt.Fprintln(os.Stderr, "usage: gocat -base <dir> <file>")
		os.Exit(2)
	}

	if err := catFile(*base, flag.Arg(0), os.Stdout); err != nil {
		fmt.Fprintf(os.Stderr, "gocat: %v\n", err)
		os.Exit(1)
	}
}

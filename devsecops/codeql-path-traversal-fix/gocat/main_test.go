package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestSafePathRejectsTraversal(t *testing.T) {
	dir := t.TempDir()
	_, err := safePath(dir, "../etc/passwd")
	if err == nil {
		t.Fatal("expected error for path traversal")
	}
}

func TestSafePathAllowsRelativeFile(t *testing.T) {
	dir := t.TempDir()
	file := filepath.Join(dir, "hello.txt")
	if err := os.WriteFile(file, []byte("ok"), 0o600); err != nil {
		t.Fatal(err)
	}

	target, err := safePath(dir, "hello.txt")
	if err != nil {
		t.Fatal(err)
	}
	if target != file {
		t.Fatalf("expected %q, got %q", file, target)
	}
}

func TestCatFileReadsInsideBase(t *testing.T) {
	dir := t.TempDir()
	file := filepath.Join(dir, "hello.txt")
	if err := os.WriteFile(file, []byte("data"), 0o600); err != nil {
		t.Fatal(err)
	}

	if err := catFile(dir, "hello.txt", os.Stdout); err != nil {
		t.Fatal(err)
	}
}

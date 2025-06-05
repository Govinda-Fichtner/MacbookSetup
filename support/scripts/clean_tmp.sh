#!/bin/zsh

# Clean temporary directories
echo "🧹 Cleaning temporary directories..."

# Clean repositories (should already be clean due to automatic cleanup)
if [[ -d "tmp/repositories" ]]; then
  echo "  ├── Cleaning tmp/repositories/"
  rm -rf tmp/repositories/*
  echo "  │   └── [SUCCESS] Repositories cleaned"
fi

# Clean test home directory (this often has persistent files)
if [[ -d "tmp/test_home" ]]; then
  echo "  ├── Cleaning tmp/test_home/"
  rm -rf tmp/test_home
  mkdir -p tmp/test_home
  echo "  │   └── [SUCCESS] Test home cleaned"
fi

# Clean any other files in tmp root
if [[ -d "tmp" ]]; then
  echo "  ├── Cleaning tmp/ root files"
  find tmp -maxdepth 1 -type f -delete
  echo "  │   └── [SUCCESS] Root files cleaned"
fi

# Check final state
echo "  └── Final state:"
if [[ -d "tmp" ]]; then
  find tmp -type f | while read -r file; do
    echo "      ├── [REMAINING] $file"
  done

  if [[ $(find tmp -type f | wc -l) -eq 0 ]]; then
    echo "      └── [SUCCESS] All temporary files cleaned"
  fi
else
  echo "      └── [INFO] No tmp directory found"
fi

echo "✅ Cleanup complete"

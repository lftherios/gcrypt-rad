#!/bin/sh
# Install git-remote-gcrypt to /usr/local/bin (or specified prefix)

set -e

PREFIX="${PREFIX:-/usr/local}"
BINDIR="${BINDIR:-$PREFIX/bin}"

if [ ! -w "$BINDIR" ]; then
    echo "Cannot write to $BINDIR. Try: sudo $0"
    exit 1
fi

cp git-remote-gcrypt "$BINDIR/"
chmod +x "$BINDIR/git-remote-gcrypt"

echo "Installed git-remote-gcrypt to $BINDIR/git-remote-gcrypt"
echo ""
echo "For SSH key support, also install age:"
echo "  macOS:        brew install age"
echo "  Debian/Ubuntu: apt install age"
echo "  From source:  go install filippo.io/age/cmd/...@latest"

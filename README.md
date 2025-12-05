# git-remote-gcrypt (Transport-Agnostic Fork)

Encrypted git remote helper with **pluggable transport backends** and **SSH key support**.

This fork of [git-remote-gcrypt](https://github.com/spwhitton/git-remote-gcrypt) adds:

1. **Transport-agnostic architecture** - Easily add new transport backends
2. **Radicle (`rad://`) support** - Private collaboration over Radicle network
3. **SSH key encryption** - Use SSH keys instead of GPG via [age](https://github.com/FiloSottile/age)

## Use Case: Private Radicle Collaboration

Use a relay node on the Radicle network for private, encrypted collaboration:

```
┌─────────────┐     encrypted      ┌─────────────────┐     encrypted      ┌─────────────┐
│   Alice     │ ──────────────────>│  Radicle Relay  │<────────────────── │    Bob      │
│ (SSH keys)  │    rad:// push     │  (allowlisted)  │    rad:// pull     │ (SSH keys)  │
└─────────────┘                    └─────────────────┘                    └─────────────┘
```

The relay node only sees encrypted blobs. Only participants with the right SSH keys can decrypt.

## Installation

```bash
# Install age for SSH key support
# macOS
brew install age

# Debian/Ubuntu
apt install age

# From source
go install filippo.io/age/cmd/...@latest

# Install git-remote-gcrypt
cp git-remote-gcrypt /usr/local/bin/
chmod +x /usr/local/bin/git-remote-gcrypt
```

## Quick Start

### With SSH Keys (Recommended)

```bash
# Create encrypted remote using Radicle
git remote add private gcrypt::rad://z6MksFqXN3Yhqk8pTJdUGLwATkRfQvwZXPqR2qMEhbS9wzpT

# Configure participants (SSH public keys)
git config remote.private.gcrypt-participants "~/.ssh/alice.pub ~/.ssh/bob.pub"

# Or use age public keys
git config remote.private.gcrypt-participants "age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p"

# Push encrypted
git push private main
```

### With GPG (Traditional)

```bash
# Create encrypted remote
git remote add cryptremote gcrypt::rad://z6MksFqXN3Yhqk8pTJdUGLwATkRfQvwZXPqR2qMEhbS9wzpT

# Configure GPG participants
git config remote.cryptremote.gcrypt-participants "KEYID1 KEYID2"

# Push encrypted
git push cryptremote main
```

## Supported Transports

| Transport | URL Format | Notes |
|-----------|------------|-------|
| **Radicle** | `rad://zXXX...` | Peer-to-peer git hosting |
| **rsync** | `rsync://user@host/path` | Efficient for large repos |
| **sftp** | `sftp://user@host/path` | Standard SFTP |
| **rclone** | `rclone://remote:path` | Any rclone backend |
| **local** | `/path/to/repo` | Local filesystem |
| **git** | Any git URL | Stores in another git repo |

All URLs are prefixed with `gcrypt::` to enable encryption.

## Configuration

### Crypto Backend Selection

```bash
# Explicit backend selection
git config gcrypt.crypto-backend age    # Use age (SSH keys)
git config gcrypt.crypto-backend gpg    # Use GPG (default)

# Auto-detection: if participants contain "ssh-" or "age1", age is used
```

### SSH Key Configuration (age backend)

```bash
# Participants: who can decrypt (public keys or key files)
git config gcrypt.participants "~/.ssh/id_ed25519.pub ~/.ssh/coworker.pub"

# Or inline SSH public keys
git config gcrypt.participants "ssh-ed25519 AAAA... ssh-ed25519 BBBB..."

# Or age public keys
git config gcrypt.participants "age1abc... age1xyz..."

# Identity: your private key for decryption
git config gcrypt.age-identity ~/.ssh/id_ed25519
```

### GPG Configuration (gpg backend)

```bash
# Participants: GPG key IDs
git config gcrypt.participants "KEYID1 KEYID2"

# Signing key
git config user.signingkey KEYID

# Additional GPG args
git config gcrypt.gpg-args "--use-agent"
```

### Per-Remote Configuration

```bash
# Remote-specific participants
git config remote.myremote.gcrypt-participants "KEY1 KEY2"

# Remote-specific crypto backend
git config remote.myremote.gcrypt-crypto-backend age

# Remote-specific identity
git config remote.myremote.gcrypt-age-identity ~/.ssh/special_key
```

### Other Options

```bash
# Require explicit --force for push
git config gcrypt.require-explicit-force-push true

# rsync flags
git config gcrypt.rsync-put-flags "-v --progress"

# Publish participant IDs (less private but fewer passphrase prompts)
git config gcrypt.publish-participants true
```

## How It Works

### Repository Format

```
Remote storage:
├── 91bd0c09...  (encrypted manifest)
├── a3f2b1c4...  (encrypted packfile 1)
├── d8e9f0a1...  (encrypted packfile 2)
└── ...
```

1. **Packfiles** are encrypted with random symmetric keys
2. **Manifest** contains refs, pack keys, and metadata
3. **Manifest** is encrypted to all participants (asymmetric)
4. File names are content hashes (reveal nothing)

### Security Model

- **Confidentiality**: All data encrypted; storage sees only random blobs
- **Integrity**: Pack files verified by hash before decryption
- **Authentication** (GPG): Manifest is signed; only listed signers accepted
- **Authentication** (age): Implicit via encryption; only key holders decrypt

### Radicle Integration

When using `rad://` URLs:

1. Encrypted data stored as blobs in a Radicle git repository
2. Relay nodes in your allowlist can sync the encrypted repo
3. They cannot read the content (no decryption keys)
4. Participants pull via Radicle, decrypt locally

## Examples

### Team Setup with SSH Keys

```bash
# Alice creates the repo
git init myproject && cd myproject
git remote add team gcrypt::rad://z6MksFqXN3Yhqk8pTJdUGLwATkRfQvwZXPqR2qMEhbS9wzpT

# Configure team members' SSH public keys
git config remote.team.gcrypt-participants \
  "~/.ssh/alice.pub /shared/keys/bob.pub /shared/keys/carol.pub"

# Initial push
echo "Secret project" > README.md
git add . && git commit -m "Initial"
git push team main

# Bob clones
git clone gcrypt::rad://z6MksFqXN3Yhqk8pTJdUGLwATkRfQvwZXPqR2qMEhbS9wzpT myproject
cd myproject
git config remote.origin.gcrypt-participants \
  "~/.ssh/alice.pub ~/.ssh/bob.pub /shared/keys/carol.pub"
git config remote.origin.gcrypt-age-identity ~/.ssh/bob
```

### Local Encrypted Backup

```bash
git remote add backup gcrypt::/mnt/usb/encrypted-backup
git config remote.backup.gcrypt-participants ~/.ssh/id_ed25519.pub
git push backup --all
```

### Using with rsync

```bash
git remote add server gcrypt::rsync://user@server.com/repos/myproject
git config remote.server.gcrypt-participants ~/.ssh/id_ed25519.pub
git push server main
```

## Checking Repository Status

```bash
# Check if a URL is a valid gcrypt repo you can decrypt
git-remote-gcrypt --check gcrypt::rad://z6Mk...

# Exit codes:
# 0   - Repo exists and can be decrypted
# 1   - Repo exists but decryption failed
# 100 - Not a gcrypt repo or inaccessible
```

## Troubleshooting

### "age encryption tool not found"

Install age: `brew install age` or `apt install age`

### "No SSH identity found for decryption"

Set your identity:
```bash
git config gcrypt.age-identity ~/.ssh/id_ed25519
```

### Push takes a long time

For git-based backends (including `rad://`), the entire history is re-uploaded on each push. Use `rsync://` for large repos if possible.

### "Repository not found" but it exists

Check network connectivity and authentication to the underlying transport.

## Adding New Transports

The transport layer is modular. To add a new transport:

1. Add URL detection in `detect_transport()`
2. Implement handler functions: `mytransport_get()`, `mytransport_put()`, `mytransport_remove()`, `mytransport_new_repo()`
3. Add cases in `GET()`, `PUT()`, `PUT_FINAL()`, `PUTREPO()`, `REMOVE()`, `CLEAN_FINAL()`

## License

GPL-3.0 (same as original git-remote-gcrypt)

## Credits

- Original git-remote-gcrypt: engla, Joey Hess, Sean Whitton
- Transport-agnostic refactoring and SSH key support: Contributors

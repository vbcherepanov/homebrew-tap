# homebrew-tap (vbcherepanov)

Tap for `total-agent-memory` and any future tools.

## Install

```bash
brew tap vbcherepanov/tap
brew install total-memory                   # or `brew install vbcherepanov/tap/total-memory`
```

Or, before PyPI publication, build from git tip:

```bash
brew install --HEAD vbcherepanov/tap/total-memory
```

## Verify formula locally (without publishing)

```bash
# Syntax check (Ruby parse only)
ruby -wc Formula/total-memory.rb

# Style audit (requires brew + Homebrew/homebrew-core access)
brew style Formula/total-memory.rb

# Strict audit (after `brew tap vbcherepanov/tap`)
brew audit --strict --new vbcherepanov/tap/total-memory
```

## After PyPI publish

1. `twine upload dist/claude_total_memory-X.Y.Z.tar.gz`
2. `curl -L https://files.pythonhosted.org/packages/source/c/claude-total-memory/claude_total_memory-X.Y.Z.tar.gz | shasum -a 256`
3. Update `url`, `sha256`, `version` lines in `Formula/total-memory.rb`
4. Commit + push this repo
5. `brew tap vbcherepanov/tap` on any Mac/Linux → `brew install total-memory` works

## Why a separate repo

Homebrew treats any GitHub repo named `homebrew-<tap>` as a tap
automatically. Putting formula here keeps the main project repo free of
Ruby packaging files.

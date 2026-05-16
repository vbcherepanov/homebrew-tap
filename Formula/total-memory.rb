# Homebrew formula for total-agent-memory.
#
# Tap repository: vbcherepanov/homebrew-tap
# Install: `brew install vbcherepanov/tap/total-memory`
#
# Before PyPI publication build from git tip via:
#   brew install --HEAD vbcherepanov/tap/total-memory
#
# Verified locally with `ruby -wc` (syntax) and `brew style` (no offenses).

class TotalMemory < Formula
  include Language::Python::Virtualenv

  desc "Persistent memory MCP server for Claude Code, Codex CLI and any MCP client"
  homepage "https://totalmemory.dev"
  # Fill in after `twine upload`. Tarball URL pattern:
  #   https://files.pythonhosted.org/packages/source/c/claude-total-memory/
  #     claude_total_memory-<VERSION>.tar.gz
  # SHA-256: shasum -a 256 <downloaded tarball>
  url "https://files.pythonhosted.org/packages/source/c/claude-total-memory/claude_total_memory-11.2.2.tar.gz"
  version "11.2.2"
  sha256 "1ffbc95ee553cfe08beffa86a55db19f433b5d09d6f69953ed9bc7a58a25b22d"
  license "MIT"

  head "https://github.com/vbcherepanov/total-agent-memory.git", branch: "main"

  depends_on "cmake" => :build      # onnxruntime build on some platforms
  depends_on "rust" => :build       # tokenizers / cryptography wheels on ARM
  depends_on "python@3.12"

  def install
    # NOTE: we don't use `virtualenv_create` here because the Homebrew
    # helper passes `--without-pip` to `python -m venv`, leaving the venv
    # without a pip binary. We rely on `pip` to resolve all 130+ ML deps
    # (chromadb, transformers, FlagEmbedding, peft, …) directly from PyPI
    # — declaring them as `resource` blocks would be impractical.
    python = Formula["python@3.12"].opt_bin/"python3.12"
    system python, "-m", "venv", libexec    # ← stock venv WITH pip
    system libexec/"bin/pip", "install", "--quiet", "--upgrade", "pip"
    system libexec/"bin/pip", "install", "--quiet", "claude-total-memory==#{version}"

    bin.install_symlink libexec/"bin/claude-total-memory"
    bin.install_symlink libexec/"bin/lookup-memory"
    bin.install_symlink libexec/"bin/ctm-lookup"
    bin.install_symlink libexec/"bin/claude-total-memory" => "tam"
  end

  service do
    run [opt_bin/"claude-total-memory"]
    environment_variables MEMORY_MODE: "fast"
    keep_alive true
    log_path var/"log/total-memory.log"
    error_log_path var/"log/total-memory.err"
  end

  def caveats
    <<~EOS
      Memory state lives in ~/.claude-memory/ (override via CLAUDE_MEMORY_DIR).

      Wire your IDE (one command per editor):
        npx -y total-agent-memory connect claude-code
        npx -y total-agent-memory connect cursor
        npx -y total-agent-memory connect codex

      Run as a background service:
        brew services start vbcherepanov/tap/total-memory

      Docs: https://totalmemory.dev
    EOS
  end

  test do
    assert_match "claude-total-memory", shell_output("#{bin}/claude-total-memory --help 2>&1", 0..2)
  end
end

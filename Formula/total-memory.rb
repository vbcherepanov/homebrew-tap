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
  url "https://files.pythonhosted.org/packages/11/28/1b9cb4cedcecbd51e7c4fec39d41de19323a9e39f36497abe1970ac28c8e/total_agent_memory-14.5.1.tar.gz"
  version "14.5.1"
  sha256 "acf37df398ab92a2f5a93f71dbcc2cc663983406e288a2fd99a64e314ee0d921"
  license "MIT"

  head "https://github.com/vbcherepanov/total-agent-memory.git", branch: "main"

  depends_on "cmake" => :build      # onnxruntime build on some platforms
  depends_on "rust" => :build       # tokenizers / cryptography wheels on ARM
  depends_on "python@3.12"

  # Prebuilt Rust wheels (orjson, py-rust-stemmers, watchfiles) carry `@rpath`
  # dylib IDs with no header room to rewrite them into the keg path. Homebrew
  # aborts relocation on the first such file and leaves the binaries it had
  # already patched unsigned, so they are killed on load on Apple silicon.
  # Python loads extension modules by path, so the `@rpath` IDs can stay.
  preserve_rpath

  def install
    # NOTE: we don't use `virtualenv_create` here because the Homebrew
    # helper passes `--without-pip` to `python -m venv`, leaving the venv
    # without a pip binary. We rely on `pip` to resolve all 130+ ML deps
    # (chromadb, transformers, FlagEmbedding, peft, …) directly from PyPI
    # — declaring them as `resource` blocks would be impractical.
    python = Formula["python@3.12"].opt_bin/"python3.12"
    system python, "-m", "venv", libexec # ← stock venv WITH pip
    system libexec/"bin/pip", "install", "--quiet", "--upgrade", "pip"
    system libexec/"bin/pip", "install", "--quiet", "total-agent-memory==#{version}"

    bin.install_symlink libexec/"bin/total-agent-memory"
    bin.install_symlink libexec/"bin/lookup-memory"
    bin.install_symlink libexec/"bin/ctm-lookup"
    bin.install_symlink libexec/"bin/total-agent-memory" => "tam"
    bin.install_symlink libexec/"bin/lookup-memory" => "tam-lookup"
    # 14.0.0: team server and the remote MCP bridge.
    bin.install_symlink libexec/"bin/tam-team"
    bin.install_symlink libexec/"bin/tam-remote"
    # Backward-compat: legacy entry-point name from v11.x for users with
    # `claude-total-memory` baked into scripts / PATH expectations.
    bin.install_symlink libexec/"bin/total-agent-memory" => "claude-total-memory"
  end

  service do
    run [opt_bin/"total-agent-memory"]
    environment_variables MEMORY_MODE: "fast"
    keep_alive true
    log_path var/"log/total-memory.log"
    error_log_path var/"log/total-memory.err"
  end

  def caveats
    <<~EOS
      Memory state lives in ~/.tam/ (override via TAM_MEMORY_DIR).
      Legacy ~/.claude-memory/ from v11.x installs is migrated automatically
      on first run, with a symlink kept for backward-compat.

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
    # The entry points speak MCP over stdio; answer an initialize request from a scratch store.
    ENV["TAM_MEMORY_DIR"] = (testpath/"tam").to_s
    ENV["MEMORY_MODE"] = "fast"
    request = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18",' \
              '"capabilities":{},"clientInfo":{"name":"brew-test","version":"1"}}}'
    %w[total-agent-memory tam].each do |cmd|
      output = pipe_output("#{bin}/#{cmd} 2>/dev/null", "#{request}\n")
      assert_match '"name":"total-agent-memory"', output
      assert_match "\"version\":\"#{version}\"", output
    end
  end
end

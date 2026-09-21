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
  url "https://files.pythonhosted.org/packages/06/4e/abd9967faceaa464385059d0c6f9670d7c482d2db464faf5f06f532c9fce/total_agent_memory-14.1.0.tar.gz"
  version "14.1.0"
  sha256 "d6a7377de3c1af13acae655acc10aefb9b0be271608ef28e128455fe17cd6b02"
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
    system python, "-m", "venv", libexec # ← stock venv WITH pip
    system libexec/"bin/pip", "install", "--quiet", "--upgrade", "pip"
    system libexec/"bin/pip", "install", "--quiet", "total-agent-memory==#{version}"

    # Rebuild orjson from source with header padding so Homebrew can rewrite
    # its `@rpath` dylib ID into the keg path; the prebuilt Rust wheel has no
    # room and `brew install` fails with "Failed changing dylib ID". This must
    # run here, not in post_install: Homebrew's cleaner removes the RECORD
    # files pip needs to replace a package. The flag goes through rustc
    # (Homebrew's rustc wrapper), because LDFLAGS never reaches the Rust
    # linker, and maturin rejects a bare major deployment target such as "26".
    ENV["MACOSX_DEPLOYMENT_TARGET"] = "#{MacOS.version.major}.0"
    ENV.append_to_rustflags "-C link-arg=-Wl,-headerpad_max_install_names"
    system libexec/"bin/pip", "install", "--quiet", "--no-cache-dir", "--no-binary", "orjson",
           "--force-reinstall", "--no-deps", "orjson"

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
    assert_match "total-agent-memory", shell_output("#{bin}/total-agent-memory --help 2>&1", 0..2)
    assert_match "total-agent-memory", shell_output("#{bin}/tam --help 2>&1", 0..2)
  end
end

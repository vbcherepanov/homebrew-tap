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
  url "https://files.pythonhosted.org/packages/dd/ba/4bb0e886cec30fe5c7ef74c689b041c1b77d2c2ec48752d7143f31dc1d27/total_agent_memory-13.0.1.tar.gz"
  version "13.0.1"
  sha256 "835fa7a52b91f768c704b32511b9d90600a06493bf96b676c4397933465b1706"
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

    bin.install_symlink libexec/"bin/total-agent-memory"
    bin.install_symlink libexec/"bin/lookup-memory"
    bin.install_symlink libexec/"bin/ctm-lookup"
    bin.install_symlink libexec/"bin/total-agent-memory" => "tam"
    bin.install_symlink libexec/"bin/lookup-memory" => "tam-lookup"
    # Backward-compat: legacy entry-point name from v11.x for users with
    # `claude-total-memory` baked into scripts / PATH expectations.
    bin.install_symlink libexec/"bin/total-agent-memory" => "claude-total-memory"
  end

  def post_install
    # Rebuild orjson from source so that its Mach-O header has enough
    # space for install_name_tool to rewrite `@rpath/orjson.so` into
    # `/opt/homebrew/opt/total-memory/...` (Rust wheels ship with a
    # tightly-packed __LINKEDIT that doesn't fit Homebrew's absolute path).
    # Without this, `brew install` prints "Failed changing dylib ID" — the
    # formula still runs, but the warning looks scary.
    ENV["MACOSX_DEPLOYMENT_TARGET"] = MacOS.version.to_s
    ENV.append "LDFLAGS", "-headerpad_max_install_names"
    system libexec/"bin/pip", "install", "--quiet", "--no-binary", "orjson",
           "--force-reinstall", "--no-deps", "orjson"
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

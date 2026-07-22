class AiAgentOps < Formula
  desc "AI agent operating harness for role-based project workflows"
  homepage "https://github.com/cschoi724/ai-agent-ops"
  url "https://github.com/cschoi724/ai-agent-ops/archive/refs/tags/v0.6.3.tar.gz"
  sha256 "4371e179145defe3a8b31927cf1501a729cb449f4c692d808510d93b88e6ae5c"

  def install
    libexec.install "VERSION"
    libexec.install "README.md", "QUICKSTART.md", "CHANGELOG.md", "LICENSE"
    libexec.install "agents", "bin", "bootstrap", "core", "docs", "models"
    libexec.install "policies", "runtime", "templates", "workflows"

    (bin/"aiops").write <<~EOS
      #!/bin/sh
      export AIOPS_CORE_HOME="#{opt_libexec}"
      exec "#{opt_libexec}/bin/aiops" "$@"
    EOS
    chmod 0755, bin/"aiops"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/aiops version")
  end
end

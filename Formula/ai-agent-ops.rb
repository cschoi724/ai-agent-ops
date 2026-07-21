class AiAgentOps < Formula
  desc "AI agent operating harness for role-based project workflows"
  homepage "https://github.com/cschoi724/ai-agent-ops"
  url "https://github.com/cschoi724/ai-agent-ops/archive/refs/tags/v0.6.2.tar.gz"
  sha256 "b2a0b3810acb87e1b8402b3790caafffcaaf578d31b9df7491b1bba3979af062"

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

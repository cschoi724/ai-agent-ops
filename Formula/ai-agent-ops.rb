class AiAgentOps < Formula
  desc "AI agent operating harness for role-based project workflows"
  homepage "https://github.com/cschoi724/ai-agent-ops"
  url "https://github.com/cschoi724/ai-agent-ops/archive/refs/tags/v0.17.2.tar.gz"
  sha256 "c7c30d1642614943f76104225f6642d192a4b2c27c78e7d4bf8209bb50b5fc8c"

  def install
    libexec.install "VERSION"
    libexec.install "QUICKSTART.md"
    (libexec/"README.md").write (buildpath/"README.md").read
    (libexec/"CHANGELOG.md").write (buildpath/"CHANGELOG.md").read
    (libexec/"LICENSE").write (buildpath/"LICENSE").read
    libexec.install ".github", "scripts"
    (libexec/"Formula").mkpath
    (libexec/"Formula/ai-agent-ops.rb").write File.read(__FILE__)
    libexec.install "adapters", "agents", "bin", "bootstrap", "core", "docs", "models"
    libexec.install "policies", "runtime", "schemas", "templates", "workflows"

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

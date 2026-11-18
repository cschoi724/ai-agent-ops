class AiAgentOps < Formula
  desc "AI agent operating harness for role-based project workflows"
  homepage "https://github.com/cschoi724/ai-agent-ops"
  url "https://github.com/cschoi724/ai-agent-ops/archive/refs/tags/v0.17.3.tar.gz"
  sha256 "b649052d53f04bb7d152bfb36a35a2ca40646c2b03da66438107f7b8dcce8f6e"

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

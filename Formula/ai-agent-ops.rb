class AiAgentOps < Formula
  desc "AI agent operating harness for role-based project workflows"
  homepage "https://github.com/cschoi724/ai-agent-ops"
  url "https://github.com/cschoi724/ai-agent-ops/archive/refs/tags/v0.11.0.tar.gz"
  sha256 "cdaf5000876bbeba117e57a81b388ab039dcf7ebc3851830c91bb0eb86264f51"

  def install
    libexec.install "VERSION"
    libexec.install "QUICKSTART.md"
    (libexec/"README.md").write (buildpath/"README.md").read
    (libexec/"CHANGELOG.md").write (buildpath/"CHANGELOG.md").read
    (libexec/"LICENSE").write (buildpath/"LICENSE").read
    libexec.install ".github", "Formula", "scripts"
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

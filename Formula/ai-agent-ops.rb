class AiAgentOps < Formula
  desc "Document-based operating system for AI agent collaboration"
  homepage "https://github.com/cschoi724/ai-agent-ops"
  url "https://github.com/cschoi724/ai-agent-ops/archive/refs/tags/v0.6.1.tar.gz"
  sha256 "13b62c63a099bc2fae8950fcedf33349f4c675f0e12ad4757f56ac30bf69f626"

  def install
    libexec.install Dir["*"]
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

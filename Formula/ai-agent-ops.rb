class AiAgentOps < Formula
  desc "Document-based operating system for AI agent collaboration"
  homepage "https://github.com/cschoi724/ai-agent-ops"
  url "https://github.com/cschoi724/ai-agent-ops.git",
      tag:      "v0.6.1",
      revision: "758e25df693fbbc371fa11fb1dee40cca2111a36"

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

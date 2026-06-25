# Homebrew formula for bwx.
#
# Installation:
#   brew tap 1121citrus/bwx https://github.com/1121citrus/bwx
#   brew install bwx
#
# Or install directly from a local clone:
#   brew install --formula ./install/homebrew/Formula/bwx.rb
class Bwx < Formula
  desc "Bitwarden Secrets Manager eXtended CLI"
  homepage "https://github.com/1121citrus/bwx"
  url "https://github.com/1121citrus/bwx/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license "AGPL-3.0-or-later"
  head "https://github.com/1121citrus/bwx.git", branch: "main"

  depends_on "bash" => :recommended

  def install
    bin.install "bin/bwx"
    lib.install Dir["lib/*"]
    (share/"bwx/include").install Dir["include/*"]

    # Patch BWX_ROOT resolution to use the Homebrew prefix instead of
    # computing it relative to BASH_SOURCE.  The original uses
    # dirname(bin/bwx)/.. which works for a git clone but not for
    # Homebrew's split layout (bin/ in one place, lib/ in another).
    inreplace bin/"bwx",
      'BWX_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"',
      "BWX_ROOT=\"#{share}/bwx\""

    # Symlink lib/ and bin/ into the share tree so the sourcing works
    (share/"bwx/lib").install_symlink Dir[lib/"*"]
    (share/"bwx/bin").install_symlink bin/"bwx"

    # Install version.txt for --version
    (share/"bwx").install "version.txt"
  end

  def caveats
    <<~EOS
      bwx wraps the Bitwarden Secrets Manager CLI (bws).
      If bws is not installed natively, bwx falls back to a
      Docker-wrapped version automatically.

      Enable tab completion by adding to ~/.bashrc:
        eval "$(bwx completion bash)"

      Or for zsh (~/.zshrc):
        eval "$(bwx completion zsh)"
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/bwx --version").strip
    assert_match "bwx", shell_output("#{bin}/bwx --help")
    assert_match "secret", shell_output("#{bin}/bwx --help")
    assert_match "complete -F", shell_output("#{bin}/bwx completion bash")
  end
end

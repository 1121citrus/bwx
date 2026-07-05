# Homebrew formula for bwx.
#
# Installation:
#   brew tap 1121citrus/bwx https://github.com/1121citrus/bwx
#   brew install --HEAD bwx
#
# Or install directly from a local clone:
#   brew install --HEAD --formula ./install/homebrew/Formula/bwx.rb
class Bwx < Formula
  desc "Bitwarden Secrets Manager eXtended CLI"
  homepage "https://github.com/1121citrus/bwx"
  license "AGPL-3.0-or-later"
  url "https://github.com/1121citrus/bwx/archive/refs/tags/v1.2.1.tar.gz"
  # Interim checksum (carried from v1.2.0) — finalized with the real
  # v1.2.1 archive checksum after the tag is pushed. See the
  # chore(homebrew) release step.
  sha256 "2d1c9621dde87da39aeb017ae4eb0f37122888f48bd870af566d7dbe58e47f53"
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
      'BWX_ROOT="$(cd "${script_dir}/.." && pwd)"',
      "BWX_ROOT=\"#{share}/bwx\""

    # Symlink lib/ and bin/ into the share tree so the sourcing works
    (share/"bwx/lib").install_symlink Dir[lib/"*"]
    (share/"bwx/bin").install_symlink bin/"bwx"

    # Install version.txt for --version
    (share/"bwx").install "version.txt"

    # Install man page
    man1.install "man/man1/bwx.1"
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
    assert_match(/^\d+\.\d+\.\d+$/, shell_output("#{bin}/bwx --version").strip)
    assert_match "bwx", shell_output("#{bin}/bwx --help")
    assert_match "secret", shell_output("#{bin}/bwx --help")
    assert_match "complete -F", shell_output("#{bin}/bwx completion bash")
  end
end

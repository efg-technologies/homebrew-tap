class Sim < Formula
  desc "Next-generation Vim in Rust that shows even what is hidden"
  homepage "https://github.com/efg-technologies/sim"
  url "https://github.com/efg-technologies/sim/releases/download/v0.3.0/sim-0.3.0.tar.gz"
  sha256 "9bc74a9c4b817166a181f75e89c5823e869d9f85807670bef8ea28f66b477f22"
  license any_of: ["MIT", "Apache-2.0"]
  head "https://github.com/efg-technologies/sim.git", branch: "main"

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args(path: "sim")
    prefix.install "LICENSE-MIT", "LICENSE-APACHE"
  end

  test do
    assert_match "sim #{version}", shell_output("#{bin}/sim --version")
  end
end

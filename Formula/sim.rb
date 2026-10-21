class Sim < Formula
  desc "Next-generation Vim in Rust that shows even what is hidden"
  homepage "https://github.com/efg-technologies/sim"
  url "https://github.com/efg-technologies/sim/releases/download/v0.2.0/sim-0.2.0.tar.gz"
  sha256 "3c08b60a95d3cf99276cbf5883a80c2dcc34ed2e4e88b80fc34c6b76341076f3"
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

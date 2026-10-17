class Sim < Formula
  desc "Next-generation Vim in Rust that shows even what is hidden"
  homepage "https://github.com/efg-technologies/sim"
  url "https://github.com/efg-technologies/sim/releases/download/v0.1.0/sim-0.1.0.tar.gz"
  sha256 "48ea9db86f92fdaa4affa9ba191559cd6fd131310c8ac88b83fe4ad12abe73a5"
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

class Sim < Formula
  desc "Next-generation Vim in Rust that shows even what is hidden"
  homepage "https://github.com/efg-technologies/sim"
  url "https://github.com/efg-technologies/sim/releases/download/v0.2.1/sim-0.2.1.tar.gz"
  sha256 "0b15b291cf84e7b17fd0e1e6e6117fac39dd59c50165b189e1116ab979eabe08"
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

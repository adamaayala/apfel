#!/usr/bin/env bash

set -euo pipefail

version=""
sha256=""
output=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      version="${2:-}"
      shift 2
      ;;
    --sha256)
      sha256="${2:-}"
      shift 2
      ;;
    --output)
      output="${2:-}"
      shift 2
      ;;
    *)
      echo "usage: $0 --version <version> --sha256 <sha256> --output <path>" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$version" || -z "$sha256" || -z "$output" ]]; then
  echo "usage: $0 --version <version> --sha256 <sha256> --output <path>" >&2
  exit 1
fi

cat > "$output" <<EOF
class Apfel < Formula
  desc "On-device Apple FoundationModels CLI and OpenAI-compatible server"
  homepage "https://github.com/Arthur-Ficial/apfel"
  url "https://github.com/Arthur-Ficial/apfel/releases/download/v${version}/apfel-${version}-arm64-macos.tar.gz"
  sha256 "${sha256}"
  license "MIT"

  def install
    bin.install "apfel"
  end

  service do
    run [opt_bin/"apfel", "--serve"]
    keep_alive true
    log_path var/"log/apfel.log"
    error_log_path var/"log/apfel.log"
  end

  def caveats
    s = <<~EOS
      apfel runs entirely on-device and requires Apple Intelligence to be enabled.

      Check model availability with:
        apfel --model-info
    EOS
    unless Hardware::CPU.arm?
      s += <<~EOS

        WARNING: This binary was built for Apple Silicon (arm64).
        It may not work on this architecture.
      EOS
    end
    s
  end

  test do
    assert_match "apfel v${version}", shell_output("#{bin}/apfel --version")
  end
end
EOF

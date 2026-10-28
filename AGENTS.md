# Review and release guidance for the sim tap

## Code Review Rules

- Report concrete P0/P1 correctness, security or data-loss issues. Flag a formula URL, version or SHA256 that does not identify the actual published sim source asset, or a change that fetches/runs untrusted code during install. Leave style to deterministic checks.
- Keep the sim tag, both crate versions, release tarball, formula and AUR metadata consistent. Never treat a tarball from main or a dry run as the published release asset; hash the actual uploaded bytes.
- Preserve the release helper's local-only contract. It must not silently push, tag, commit, publish or invoke gh. Changes to that contract, credentials, standing access or distribution permissions require separate scope review.

## Review and verification

Batch a review-ready diff and use the existing Codex GitHub integration once. Reuse review/CI evidence for the same HEAD; review the delta again when HEAD changes. A reaction, silence or ambiguous comment is not approval. Keep independent review tied to the exact latest HEAD, inspect all applicable checks, and never fabricate Approved or deployment records or bypass protection. Use a matching-head merge after a final readback.

Normal requested changes within existing authority do not need repeated owner confirmation. New permissions, persistent access/credentials, spending, destructive data operations, authentication/billing policy or uncertain scope remain separate boundaries. Do not start heavy local builds while Gold renders.

## Distribution verification

There is no GitHub PR CI on main as observed2026-10-28. Existing `tests/release_test.sh` checks that the helper never publishes; it needs makepkg and an isolated AUR fixture. Its exit0 on a missing makepkg means SKIPPED, not a passing test. Reuse the existing shell/Ruby syntax and release-fixture validation appropriate to the change; a source release also requires sim's own checks.

`tools/release.sh` prepares files and prints the draft-release command. Preserve the existing explicit publish step: this guide does not create a release or choose a new version. Before distribution, tie the sim tag/source SHA to a tested build and the actual release asset digest, then the formula/AUR commit. Retain the previous working formula and release asset as the recovery target; never delete historical releases or change their bytes. A tap commit alone is not proof that users received a working sim binary.


<!-- SPDX-FileCopyrightText: Jukka Aho -->
<!-- SPDX-License-Identifier: MIT -->

# Release compatibility CI

This package has an independent `Release CI` workflow for trusted manual runs
and new version tags. It checks compatibility; it does not publish a release,
change package versions, move tags or register metadata.

## Run a candidate before publication

Use GitHub Actions **Release CI → Run workflow** on `master`. Set `source_ref`
to a trusted tag, branch or full SHA; an empty input uses the workflow commit.
For example:

```bash
gh workflow run release-ci.yml --repo ahojukka5/AbaqusReader.jl --ref master \
  -f source_ref=<full-candidate-sha>
```

The workflow resolves this ref once, and all matrix legs check that exact
commit. Logs retain the commit/tree, package path/version and exact Julia
patch version. Root version tags must agree with the root Project.toml.
The automatic tag run verifies the immutable tagged source after publication;
it does not replace running the candidate beforehand.

## Matrix and results

As of 31 October 2026 the selectors are `lts`, `1.11`, `1.12`, `1`: current LTS (1.10),
intervening minors, current stable (1.13), and an exact declared modern minimum
when distinct. Review the list when upstream LTS/stable or the package minimum
changes. A broad historical `julia = "1"` declaration does not demonstrate
support for pre-LTS runtimes; this workflow qualifies the listed versions only.

Each leg independently checks the unchanged Julia compatibility bound,
registry/dependency setup, loading in a new source consumer, and the complete
existing `Pkg.test()` target. A path identifies only the selected candidate;
sibling pins and package compatibility are not rewritten to obtain a pass.
Older Julia resolvers may reject `[sources]` or current dependency metadata;
that is a failed qualification, not evidence that numerical tests ran.

The source consumer deliberately checks the package as a dependency. Root
`[sources]` declarations and committed lockfiles may behave differently there
than in a root test project. Both outcomes remain visible. Existing committed
lockfiles are retained; no developer Manifest or shared user project is added.

Jobs use fresh writable package depots plus Julia's shipped runtime resources,
no user/project cache, one Julia/BLAS thread, at most one simultaneous leg per
repository and a 90-minute per-leg bound. Both jobs run on GitHub-hosted
`ubuntu-latest` runners. The self-hosted controller refuses this public
repository, so a `self-hosted` label stays queued. Contents permission stays
read-only. Secret-backed Git helpers, when needed,
are process-scoped environment configuration, not persistent runner config.
Julia toolchain availability in the image is tracked separately; this workflow
retains the established setup-julia selector and claims no image rollout.

Portable Bash timing preserves phase exit status. Continuation records all
outcomes; final aggregation fails for any failed, skipped or incomplete check.
Matrix fail-fast is disabled. Report pending as pending and classify failures
from actual logs before claiming runtime compatibility. Tests and tolerances
are unchanged. This source-level check does not replace registry-installation,
native-artifact/platform, optional accelerator, MPI or downstream qualification.

Policy context: [Julia LTS release qualification](https://github.com/ahojukka5/OodiHandbook/issues/251).

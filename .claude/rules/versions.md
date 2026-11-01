# Versions

The version lives in `VERSION` and in signed tags (`vX.Y.Z`). Whoever works on the repo decides when to cut one; the owner asked for small, steady versions, never one big jump that holds weeks of work.

- **Patch (`X.Y.Z+1`)**: fixes only, no new feature. Cut it once a fix (or a few related ones) is checked on screen.
- **Minor (`X.Y+1.0`)**: one or more finished features, checked on screen. Cut it when a feature set is complete, not after every commit, and not while one of its parts is half done.
- **Major**: only when the owner says so.
- Never skip a number, and never tag over a known regression introduced since the last tag: fix it first or leave it out.
- A version is the whole of the `release` skill ([.claude/skills/release/SKILL.md](../skills/release/SKILL.md)): the `VERSION` commit, the signed tag, the push of `master` and the tag, and the GitHub release with `gh release create`. Say in the reply that a version was cut, with its release link. Outside a release, commits stay local until the owner asks for a push.

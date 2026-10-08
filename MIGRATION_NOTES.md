# Migration Notes

## Current Requirements

- Ruby 3.3 or newer
- Rails 8.1 or newer
- Recording Studio 4.x (`~> 4.2` in the gemspec; dummy GitHub tag `v4.3.0`)
- Accessible dummy tag `v0.10.1` and Root Switchable dummy tag `v0.5.1`
- FlatPack dummy tag `v0.1.196`
- `aws-sdk-s3` (gemspec runtime dependency for Cloudflare R2)
- Public RubyGems and GitHub access for dependency installation

## 0.4.0

- Migrate to add `revision`, `purge_error`, and `purged_at` on `recording_studio_artifacts`.
- `RecordingStudioArtifacts.unpublish(id:)` destroys the row after deleting the R2 object.
- See `CHANGELOG.md` `[0.4.0]` upgrade notes.

## Verification

Install both bundles and run the complete gem and dummy app test path:

```bash
bundle install
BUNDLE_GEMFILE=test/dummy/Gemfile bundle install
bundle exec rake test:all
```

Run the dummy app from its directory for browser verification:

```bash
cd test/dummy
bin/dev
```

Use the [FlatPack repository](https://github.com/bowerbird-app/flatpack) and the live FlatPack demo linked from the top-level README for current component documentation.

# Migration Notes

## Current Requirements

- Ruby 3.3 or newer
- Rails 8.1 or newer
- Recording Studio 4.2 through 6.x (`>= 4.2, < 7` in the gemspec; dummy GitHub tag `v6.10.0`)
- Accessible dummy tag `v0.37.0`, Trashable dummy tag `v0.14.1` (`require: false`), Root Switchable dummy tag `v0.15.0`, Metrics dummy tag `v0.8.0`, and Cache dummy tag `v0.6.3`
- FlatPack dummy tag `v0.1.366`
- Dummy database includes core 6.9's `recording_studio_events.root_recording_id` migration. Hosts that write events on Recording Studio 6.9+ need that column. This gem does not add an artifacts table migration for it.
- `aws-sdk-s3` (gemspec runtime dependency for Cloudflare R2)
- Public RubyGems and GitHub access for dependency installation

## 0.4.8

- No schema change for hosts that already migrated `recording_studio_artifacts`.
- The migrations generator now stamps each copied file later than the previous one. If a host generated both artifacts migrations in one second and has not run them, delete those two files and generate again. Equal timestamps sorted the revision migration ahead of `create_table`.
- See `CHANGELOG.md` `[0.4.8]` upgrade notes.

## 0.4.7

- No schema change. Development lockfiles move to Rails `8.1.4.1`, `nokogiri` `>= 1.19.5`, `loofah` `>= 2.25.3`, and `rails-html-sanitizer` `>= 1.7.2`.
- See `CHANGELOG.md` `[0.4.7]` upgrade notes.

## 0.4.6

- No schema change.
- See `CHANGELOG.md` `[0.4.6]` upgrade notes.

## 0.4.5

- No schema change. The gemspec `recording_studio` range is `>= 4.2, < 7`.
- See `CHANGELOG.md` `[0.4.5]` upgrade notes.

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

The gem suite fails if line coverage of `app/` and `lib/` drops below 94%.

Run the dummy app from its directory for browser verification:

```bash
cd test/dummy
bin/dev
```

Use the [FlatPack repository](https://github.com/bowerbird-app/flatpack) and the live FlatPack demo linked from the top-level README for current component documentation.

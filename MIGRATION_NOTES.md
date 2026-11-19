# Migration Notes

## 0.6.0

- No artifacts schema change. Development pins move to Recording Studio `v7.8.0`, Accessible `v0.55.0`, Trashable `v1.2.3`, Root Switchable `v0.16.1`, Metrics `v0.9.2`, Cache `v0.7.1`, and FlatPack `v0.2.0`. Gemspec range stays `>= 7.0, < 8.0`.
- Hosts MUST run the Recording Studio 7.4, 7.5 and 7.7 migrations if they have not. This gem does not ship them, and the dummy app does not copy them.
- flat_pack 0.2.0 is supported; hosts moving to 0.2 must remove the manual `flat_pack/heroicons` importmap pin and any `flat-pack--icon` controller registration.
- See `CHANGELOG.md` `[0.6.0]` upgrade notes.

## 0.5.2

- No artifacts schema change. Development pins move to Recording Studio `v7.7.1`, Accessible `v0.54.0`, Trashable `v1.2.0`, Metrics `v0.9.1`, and FlatPack `v0.1.378`. Root Switchable stays `v0.16.0`. Cache stays `v0.7.0`. Gemspec range stays `>= 7.0, < 8.0`.
- Recording Studio 7.4, 7.5, and 7.7 add root-index migrations. Hosts run those core migrations. This gem does not ship them.
- See `CHANGELOG.md` `[0.5.2]` upgrade notes.

## Current Requirements

- Ruby 3.3 or newer
- Rails 8.1 or newer
- Recording Studio 7.x (`>= 7.0, < 8.0` in the gemspec; dummy GitHub tag `v7.8.0`)
- Accessible dummy tag `v0.55.0`, Trashable dummy tag `v1.2.3` (`require: false`), Root Switchable dummy tag `v0.16.1`, Metrics dummy tag `v0.9.2`, and Cache dummy tag `v0.7.1`
- FlatPack dummy tag `v0.2.0`
- Dummy database includes core 6.9's `recording_studio_events.root_recording_id` migration. Hosts that write events on Recording Studio 6.9+ need that column. This gem does not add an artifacts table migration for it.
- `aws-sdk-s3` (gemspec runtime dependency for Cloudflare R2)
- Public RubyGems and GitHub access for dependency installation

## 0.5.1

- No artifacts schema change. Development pins move to Recording Studio `v7.3.0`, Accessible `v0.45.1`, Trashable `v1.0.0`, Root Switchable `v0.16.0`, Metrics `v0.9.0`, Cache `v0.7.0`, and FlatPack `v0.1.377`.
- Root and dummy locks move `puma` to `8.1.1`.
- See `CHANGELOG.md` `[0.5.1]` upgrade notes.

## 0.5.0

- Gemspec `recording_studio` range is `>= 7.0, < 8.0`.
- No artifacts schema change. Development pins move to Recording Studio `v7.0.0`. Create roots with `RecordingStudio.create_root_recording!`. `root_recording_for` only finds an existing root.
- Dummy lock moves `msgpack` to `1.8.7`.
- See `CHANGELOG.md` `[0.5.0]` upgrade notes.

## 0.4.9

- Gemspec `recording_studio` upper bound is `< 8.0`. The floor stays `>= 4.2`.
- No schema change. Development pins stay on core 6 (`v6.10.0`).
- See `CHANGELOG.md` `[0.4.9]` upgrade notes.

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

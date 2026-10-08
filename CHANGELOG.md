# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.0] - 2026-10-08

### Added
- `RecordingStudioArtifacts.unpublish(id:)` deletes the R2 object, purges the
  public URL, and **destroys** the Artifact row.
- Artifact `before_destroy` CDN cleanup so destroying a row does not leave R2 orphans.
- Integer `revision` column; each publish/update bumps it and passes it to
  `PublishArtifactJob`.
- `purge_error` / `purged_at` columns for purge outcomes after a successful upload.
- Docs: public bearer-URL warnings (UUID is not access control; separate domain for
  user-content HTML) in README and [`docs/CDN.md`](docs/CDN.md).

### Changed
- Publish serializes per artifact with a DB row lock (`with_lock`) and skips stale
  revisions so out-of-order jobs never flip status/etag on a newer revision.
- Once R2 upload succeeds, the artifact is marked `published`. Purge failures no
  longer mark the artifact failed or trigger re-upload retries.
- `PublishArtifactJob` sets `enqueue_after_transaction_commit = true` and raises
  when the artifact row is missing (no silent return that leaves `pending` forever).
- `aws-sdk-s3` is a gemspec runtime dependency. Hosts no longer add it manually.
- Upload `LoadError` (and other failures) mark the artifact `failed` so it cannot
  stick in `uploading`.

### Upgrade notes
- Bump to `recording_studio_artifacts` `0.4.0`.
- Run `bin/rails generate recording_studio_artifacts:migrations` then `db:migrate`
  (adds `revision`, `purge_error`, `purged_at`).
- Remove any host `gem "aws-sdk-s3"` that existed only for this gem (optional cleanup).
- Drain or ignore in-flight `PublishArtifactJob` jobs enqueued with a single
  `artifact_id` argument; 0.4.0 jobs take `(artifact_id, revision)`.
- `publish` / `update` / public URL shape stay backward compatible for Embeddable.

## [0.3.0] - 2026-10-07

### Added
- Cloudflare R2 CDN publish: `Artifact` model, `RecordingStudioArtifacts.publish` /
  `.update` service API, `PublishArtifactJob`, optional Cloudflare cache purge.
- Host config via `ARTIFACT_CDN_*` ENV, initializer attrs, and
  `credentials.dig(:recording_studio_artifacts, :cdn, ...)`.
- Docs: [`docs/CDN.md`](docs/CDN.md) for DNS/R2 custom domain ownership and consumer usage.
- Dummy MemoryStorage wiring + integration tests for stable URL overwrite-on-update.

### Changed
- Renamed gem identity from the addon template to `recording_studio_artifacts` (`0.3.0`).
- Dummy and root GitHub tags: Recording Studio `v4.2.1` → `v4.2.2`.

### Upgrade notes
- Point host and dummy Gemfiles at Recording Studio `v4.2.2`.
- Run `bin/rails generate recording_studio_artifacts:migrations` then `db:migrate`.
- Set `ARTIFACT_CDN_*` (or credentials) and add `gem "aws-sdk-s3"` in production hosts.
- Hosts own R2 custom domain / DNS; the gem only reads configured public domain + path.

## [0.2.3] - 2026-10-01

### Changed
- Dummy and root GitHub tags: Recording Studio `v4.2.0` → `v4.2.1`, Accessible `v0.9.1` → `v0.10.1`, Root Switchable `v0.5.0` → `v0.5.1`, FlatPack `v0.1.177` → `v0.1.196`.
- Root and dummy lockfiles refreshed to current releases, including Rails `8.1.4`. The gem test suite requires `minitest-mock` because Minitest 6 moved `Object#stub` out of minitest.
- Dummy `image_processing` constraint `~> 1.2` → `~> 2.2`. `ruby-vips` is a direct dependency with `require: false`, because image_processing 2 treats the processor as optional and the app should boot before libvips is installed.
- Dummy schema includes the Accessible 0.10 `recording_studio_access_invitations` table.

### Fixed
- Dummy Tailwind now scans the installed FlatPack components and Recording Studio views. `tailwindcss:build` links those engines under `test/dummy/vendor/engines`, because git gems are checked out as `bundler/gems/<name>-<rev>` and the old `vendor/bundle/**/flatpack/` glob never matched.
- Dummy layouts load `flat_pack/application` (component CSS such as `.fp-button`) on both the Devise layout and the Recording Studio default layout.
- Dummy importmap pins `flat_pack/tiptap` and `flat_pack/local_time`, matching the FlatPack install contract.

### Upgrade notes
- Point host and dummy Gemfiles at Recording Studio `v4.2.1`, Accessible `v0.10.1`, Root Switchable `v0.5.1`, and FlatPack `v0.1.196`.
- Run `bin/rails generate recording_studio_accessible:migrations`, then `bin/rails db:migrate`, to add access invitations.
- Rebuild Tailwind after the FlatPack tag bump: `bin/rails tailwindcss:build`.
- Hosts still on `gem "image_processing", "~> 1.2"` should move to `~> 2.2` and add `gem "ruby-vips"` (or `gem "mini_magick"`).

## [0.2.2] - 2026-09-11

### Changed
- Gemspec `recording_studio` floor `~> 4.1` → `~> 4.2` so copied addons match Accessible 0.7+.
- Dummy Accessible tag `v0.6.0` → `v0.9.1`; FlatPack tag `v0.1.133` → `v0.1.177`. Recording Studio stays `v4.2.0`; Root Switchable stays `v0.5.0`.
- Root `Gemfile.lock` Rails `8.1.1` → `8.1.3.1` (with `json` `2.21.2`, `mail` `2.9.1`, `nokogiri` `1.19.4`) to match the dummy host lock and Active Storage CVE-2026-66066.
- Extra Cloud Agent skills now come from the plugin catalog (`skill-sources.json`) instead of a hardcoded extra URL. A missing or invalid catalog is skipped so Recording Studio skills still fetch. Failures still warn and exit 0.
- Docs and pin tests no longer mention `recording_studio/v3.0.0`, FlatPack `v0.1.133`, or Accessible `v0.6.0`.

### Added
- After skills, the Cloud Agent fetch hook lists plugin `*.mdc` rules from `RecordingStudio_cursor_plugin` into `.cursor/rules/` (gitignored, not packaged). A missing rules directory warns and skips. Failures still exit 0.
- Cloud Agent skill-fetch hook so copied addons load Recording Studio skills at Build time. `.cursor/environment.json` names the environment `recording-studio-gem-template`. `install` is `.cursor/install.sh`, which runs `.cursor/fetch-skills.sh` after provisioning. `snapshot` is omitted on purpose so Builds run install instead of reusing a laptop Personal snapshot. The script lists `recording-studio-*` skill ids from the public GitHub contents API and writes each `SKILL.md` into `.cursor/skills/` (gitignored, not packaged). Failures warn and still exit 0.
- Dummy Accessible migration for `depends_on_recording_id` (Accessible 0.8+).

### Upgrade notes
- Bump addon gemspecs to `spec.add_dependency "recording_studio", "~> 4.2"`.
- Point host/dummy Gemfiles at Accessible `v0.9.1` and FlatPack `v0.1.177` (Recording Studio tag stays `v4.2.0`).
- Run `bin/rails generate recording_studio_accessible:migrations` then `bin/rails db:migrate`. Do not hand-edit Accessible tables.
- Rebuild Tailwind after the FlatPack tag bump: `bin/rails tailwindcss:build`.
- Align root gem-suite `Gemfile.lock` Rails to `8.1.3.1` if it is still on `8.1.1`.

## [0.2.1] - 2026-09-01

### Added
- Full Cloud Agent development environment. `.cursor/install.sh` now provisions the whole stack at Build time on Cursor's default image — Ruby (pinned by `.ruby-version`), PostgreSQL 16, gem dependencies for both the gem and the dummy host app, the seeded dummy database, and compiled Tailwind/FlatPack CSS — then runs the existing `.cursor/fetch-skills.sh`. `snapshot` stays omitted so Builds run `install` as before.
- `.cursor/start.sh` per-boot hook that starts PostgreSQL and waits for readiness.
- `.cursor/environment.json` now declares `start` plus `rails-server` and `tailwind-watch` terminals and exposes port 3000, so a fresh Cloud Agent boots straight into a running, signed-in-ready dummy app.

### Notes
- The install script is idempotent; running it against a warm machine reuses the existing Ruby, packages, and gems.
- No gem runtime code changed. `.cursor/` files are excluded from the packaged gem.

## [0.2.0] - 2026-08-21

New addons copied from this template are born on Recording Studio 4.x.

### Added
- Gemspec dependency `recording_studio`, `~> 4.1`
- Dummy host wiring for Accessible (`enable_capability(:accessible, on: Workspace)`) and an opt-in `RecordingStudio::Capabilities::Example.to` mixin. `.to` wraps core 4.2.0 `include_for` (not a fourth verb, and not a raw `enable_capability` / `set_capability_options` path). Installing the gem does not enable the mixin globally; only dummy Workspace opts in.
- `bin/rename_gem` leftover-identity rewrite/verification for README, homepage, and changelog URLs that still point at the addon template homepage

### Changed
- Dummy GitHub tags: Recording Studio `v4.2.0`, Accessible `v0.6.0`, Root Switchable `v0.5.0`, FlatPack `v0.1.133`
- Dummy authenticated layout is Recording Studio's default layout plus FlatPack CSS/JS; Devise keeps its own sign-in layout
- Dummy app security pins: Rails `8.1.3.1`, `json` `2.21.2`, `mail` `2.9.1`, Brakeman `8.0.6`
- Require `RecordingStudio::Hooks` and `RecordingStudio::Services::BaseService` from core instead of shipping copies

### Removed
- Copied `lib/recording_studio_artifacts/hooks.rb` and `lib/recording_studio_artifacts/services/base_service.rb`
- Product-shipped `ExampleService`
- Custom `flat_pack_sidebar` authenticated shell

### Upgrade notes
- Point dummy or host Gemfiles at Recording Studio `v4.2.0` (not `recording_studio/v3.0.0`)
- Add `spec.add_dependency "recording_studio", "~> 4.1"` to addon gemspecs
- Include `RecordingStudio::UsesDefaultLayout` (or set `layout "recording_studio/default_layout"`) for authenticated screens
- Delete any copied Hooks or BaseService files and require the core classes
- Keep recordable declarations; they are required, not a v3-only concern
- If Accessible is bundled, call `RecordingStudio.enable_capability(:accessible, on: Workspace)` (or your root type)

## [0.1.2] - 2026-07-21

### Changed
- Bumped the dummy app FlatPack dependency from `v0.1.33` to `v0.1.129`

## [0.1.1] - 2026-04-28

### Changed
- Bumped the dummy app FlatPack dependency from `0.1.2` to `0.1.33` and pinned it by tag in `test/dummy/Gemfile`

## [0.1.0] - 2025-12-04

### Added
- Initial release
- Rails mountable engine structure
- PostgreSQL with UUID primary keys support
- TailwindCSS v4 integration
- GitHub Codespaces devcontainer configuration
- Docker Compose setup with PostgreSQL and Redis
- Install generator for host applications
- Comprehensive README and documentation
- Basic test suite with Minitest

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_artifacts/compare/v0.2.3...HEAD
[0.2.3]: https://github.com/bowerbird-app/RecordingStudio_artifacts/releases/tag/v0.2.3
[0.2.2]: https://github.com/bowerbird-app/RecordingStudio_artifacts/releases/tag/v0.2.2
[0.2.1]: https://github.com/bowerbird-app/RecordingStudio_artifacts/releases/tag/v0.2.1
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_artifacts/releases/tag/v0.2.0
[0.1.2]: https://github.com/bowerbird-app/RecordingStudio_artifacts/releases/tag/v0.1.2
[0.1.1]: https://github.com/bowerbird-app/RecordingStudio_artifacts/releases/tag/v0.1.1
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_artifacts/releases/tag/v0.1.0

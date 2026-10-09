# RecordingStudioArtifacts

Rails engine that publishes cached HTML/JSON/YAML (and similar) artifacts to
**Cloudflare R2** and returns a stable public URL. Third-party gems (for example
RecordingStudio Embeddable, later) call the service API only — no model mixin in v1.

## What's Included

- **Artifact** model (UUID primary key used in the public URL)
- **Service API**: `RecordingStudioArtifacts.publish` / `.update` / `.unpublish`
- **ActiveJob** upload to R2 with optional Cloudflare cache purge (overwrite same key)
- **Host-owned DNS / R2 custom domain** — gem reads subdomain, domain, and path prefix from config/credentials
- **Dummy app** with MemoryStorage so publish works without real R2 keys
- Recording Studio 4.x, Devise, FlatPack, and sample Workspace/Folder/Page recordables for host validation

See [`docs/CDN.md`](docs/CDN.md) for ENV/credential keys, DNS ownership, and consumer usage.

**Public bearer URLs:** artifact URLs are public. The UUID is not access control.
Do not publish protected or embargoed content. When published HTML may contain
user content, serve it from a separate domain — not a subdomain of the app's
cookie domain. See [`docs/CDN.md`](docs/CDN.md).

### Consumer API (quick)

```ruby
result = RecordingStudioArtifacts.publish(
  body: html_or_json,
  content_type: "text/html; charset=utf-8",
  source: { gem: "my_consumer", id: "..." }
)
result.value[:public_url]
# => https://{subdomain}.{domain}/recording_studio_artifacts/{uuid}

RecordingStudioArtifacts.update(id: result.value[:artifact].id, body: new_body, content_type: "text/html")
# same URL forever (R2 overwrite + optional purge)

RecordingStudioArtifacts.unpublish(id: result.value[:artifact].id)
# deletes the R2 object, purges the URL, destroys the Artifact row
```

Authenticated dummy pages use Recording Studio's shared default layout (`RecordingStudio::UsesDefaultLayout`) plus FlatPack CSS and JS. Devise keeps its own sign-in layout. Dummy `/docs/*` pages stay in the dummy app as a host-app sandbox; they are not the product README.

## Quick Start

### Cursor Cloud Agent (Recommended)

A Cloud Agent boots this repo into a ready-to-use dev environment with no manual steps. The setup lives in `.cursor/`:

- `install.sh` provisions Ruby (pinned by `.ruby-version`), PostgreSQL 16, all gems, the seeded dummy database, and compiled CSS at build time, then fetches Recording Studio skills.
- `start.sh` starts PostgreSQL on every boot.
- `environment.json` runs the `rails-server` and `tailwind-watch` terminals and exposes port 3000.

Open port 3000 and sign in at `/users/sign_in`. No environment variables are required — the dummy app's `database.yml` defaults match the provisioned PostgreSQL cluster.

### GitHub Codespaces

1. Click **Code** → **Codespaces** → **Create codespace**
2. Wait for setup to complete
3. Run:
   ```bash
   cd test/dummy
   bin/rails db:setup
   bin/dev
   ```
4. Open port 3000 — you'll land on the dummy app home page and can sign in at `/users/sign_in`

The dummy app is intended as a host-app validation surface for authentication, FlatPack rendering, Tailwind source scanning, and Recording Studio route wiring.

Dummy credentials (`test/dummy/config/credentials.yml.enc`) are encrypted with the shared RecordingStudio_* development master key. Set `RAILS_MASTER_KEY` or put that key in `test/dummy/config/master.key` (gitignored). Keep the encrypted file; do not generate a per-repo dummy key. CDN keys belong under `recording_studio_artifacts.cdn` (see `docs/CDN.md`); until the shared credentials file is refreshed, prefer `ARTIFACT_CDN_*` env vars.

### Login Credentials

| Field    | Value             |
|----------|-------------------|
| Email    | admin@admin.com   |
| Password | Password          |

The login form is prefilled with these credentials for fast access.

### Useful Routes

- `/` — dummy app home page
- `/users/sign_in` — Devise sign-in page
- `/recording_studio` — redirect to `/` while the mounted Recording Studio engine remains data/API-focused
- `/docs/install`, `/docs/config`, `/docs/recordable_types`, `/docs/recordings_tree`, `/docs/gem_views`, `/docs/methods` — dummy-only starter pages

The home page in `test/dummy/app/views/home/index.html.erb` is a starting point for a minimal demo of the gem's primary behavior. Keep deeper explanations on the dummy docs pages, not in this README.

## Architecture

### Root Recording Pattern

This template follows Recording Studio's root recording pattern:

- **Workspace** is the top-level recordable
- **Folder** and **Page** demonstrate nested recordables under the workspace root
- Each configured recordable declares `recording_studio_recordable(...)`; strict declaration validation stays enabled
- A root `RecordingStudio::Recording` wraps the Workspace
- `Current.actor` is set from `current_user` (Devise) in `ApplicationController`

### Extending Recording Studio

To add new recordable types:

1. Create your model (e.g., `Page`, `Comment`)
2. Register it in `config/initializers/recording_studio.rb`:
   ```ruby
   RecordingStudio.configure do |config|
     config.recordable_types = ["Workspace", "YourNewType"]
   end
   ```
3. Declare whether the model can be a root and which parents may contain it:
   ```ruby
   class YourNewType < ApplicationRecord
     recording_studio_recordable label: "Your new type",
                                 root: false,
                                 allowed_parent_types: ["Workspace", "Folder"]
   end
   ```
4. Validate declarations and create recordings under the root:
   ```ruby
   RecordingStudio.validate_recordable_declarations!
   root_recording = RecordingStudio.root_recording_for(workspace)
   root_recording.record(YourNewType) do |record|
     record.title = "Example"
   end
   ```

### Recordable Declarations

Every configured ActiveRecord recordable type must declare its hierarchy rules. Declarations are required; they are not version-specific.

- `Workspace` declares `root: true`
- `Folder` and `Page` declare `root: false, allowed_parent_types: ["Workspace", "Folder"]`
- `config.require_recordable_declarations = true` remains enabled in the dummy app initializer

Useful console checks:

```ruby
RecordingStudio.validate_recordable_declarations!
RecordingStudio.root_recordable_types
RecordingStudio.allowed_parent_types_for("Page")
```

### Capabilities

Capability mixins are opt-in. Installing this gem does not enable mixins on host types.

The dummy Workspace enables Accessible because that addon is bundled:

```ruby
RecordingStudio.enable_capability(:accessible, on: Workspace)
```

The template also ships one example mixin that uses core 4.2.0's `include_for` factory:

```ruby
include RecordingStudio::Capabilities::Example.to(label: "dummy workspace")
```

`.to` wraps `RecordingStudio::Capabilities.include_for`. It does not add a fourth verb and it does not call `enable_capability` / `set_capability_options` itself. Folder and Page stay without the example mixin.

Use core `RecordingStudio::Hooks` and `RecordingStudio::Services::BaseService`. Do not copy those classes into a new addon.

### FlatPack UI Components

All views use FlatPack ViewComponents. Available components include:

- `FlatPack::Button::Component` — Buttons (`:primary`, `:secondary`, `:ghost`)
- `FlatPack::Card::Component` — Cards (`:default`, `:elevated`, `:outlined`)
- `FlatPack::Alert::Component` — Alerts (`:success`, `:error`, `:warning`, `:info`)
- `FlatPack::Badge::Component` — Status badges
- `FlatPack::Table::Component` — Data tables
- `FlatPack::TextInput::Component`, `EmailInput`, `PasswordInput` — Form inputs
- `FlatPack::PageNav::Component` — Default-layout page navigation
- `FlatPack::PageTitle::Component` — Page titles

Use the live FlatPack demo app at [flatpack.bowerbird.io](https://flatpack.bowerbird.io/) as the approved UI reference for current shared patterns. Its component table is the fastest way to discover available FlatPack components before introducing new custom UI.

See the [FlatPack README](https://github.com/bowerbird-app/flatpack) for full documentation.

## Tech Stack

| Component       | Version |
|-----------------|---------|
| Ruby            | 3.3+    |
| Rails           | 8.1+    |
| PostgreSQL      | 16      |
| TailwindCSS     | 4       |
| RecordingStudio | 4.x (`~> 4.2` in the gemspec; dummy GitHub tag `v4.4.0`) |
| Accessible      | dummy GitHub tag `v0.13.0` |
| Root Switchable | dummy GitHub tag `v0.6.0` |
| FlatPack        | dummy GitHub tag `v0.1.196` |
| Devise          | latest  |

The dummy Gemfile keeps `github:` sources so Bundler can fetch those gems. The gemspec still pins `recording_studio` to `~> 4.2` so copied addons declare the core dependency even when GitHub is the fetch source.

## Documentation

The original gem template documentation is preserved in `docs/recording_studio_artifacts/` as architectural reference material. Use it as background on the engine conventions; this README and the dummy app are the source of truth for the Recording Studio addon workflow.

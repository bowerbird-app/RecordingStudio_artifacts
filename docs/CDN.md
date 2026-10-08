# CDN publish — Cloudflare R2

Reusable artifact publishing for Recording Studio addons. The gem owns the
`Artifact` record, service API, and upload job. The **host** owns Cloudflare R2
bucket setup, custom domain / DNS, and credentials.

Embeddable (and other consumers) should call the service API only — no model mixin
in v1. Do not wire RecordingStudio_Embeddable in this gem.

## Public bearer URLs (not access control)

Artifact URLs are **public bearer URLs**. Anyone who has the UUID (or the full
URL) can fetch the object. The UUID is an opaque identifier, **not** an access
control mechanism.

- Do **not** publish protected, private, or embargoed content through this gem.
- When published HTML may contain user-generated content, serve artifacts from a
  **separate domain** — not a subdomain of the app's cookie domain — so a
  compromised artifact cannot read session cookies via same-site rules.

## Public URL shape

Default:

```text
https://{subdomain}.{domain}/{path_prefix}/{artifact_uuid}
```

| Part | Default | Configurable |
|------|---------|--------------|
| `subdomain` | _(required)_ | config / `ARTIFACT_CDN_SUBDOMAIN` / credentials |
| `domain` | _(required)_ | config / `ARTIFACT_CDN_DOMAIN` / credentials |
| `path_prefix` | `recording_studio_artifacts` | config / `ARTIFACT_CDN_PATH_PREFIX` / credentials |
| `artifact_uuid` | Artifact primary key | created by the gem |

Optional override: set `public_base_url` / `ARTIFACT_CDN_PUBLIC_BASE_URL` to a full
origin (e.g. `https://cdn.example.com`) instead of assembling subdomain + domain.

R2 object key equals the path section: `{path_prefix}/{artifact_uuid}`. Content
updates **overwrite the same key** and optionally purge Cloudflare so the public
URL never changes.

## Host DNS / R2 custom domain

The gem does **not** create DNS records or attach custom domains via the
Cloudflare API. Hosts must:

1. Create an R2 bucket and API token (Object Read & Write).
2. Attach a public custom domain / r2.dev subdomain in the Cloudflare dashboard
   (or CNAME the subdomain to the R2 bucket hostname).
3. Put subdomain + apex domain (or `public_base_url`) into ENV / credentials.
4. Optionally create a Cloudflare API token with Zone.Cache Purge so overwrites
   invalidate edge cache immediately.

## Credentials / env vars

Resolve order: explicit `config.*` → ENV →
`Rails.application.credentials.dig(:recording_studio_artifacts, :cdn, ...)`.

| Purpose | ENV | Credentials dig | Config attr |
|---------|-----|-----------------|-------------|
| Public subdomain | `ARTIFACT_CDN_SUBDOMAIN` | `:subdomain` | `cdn_subdomain` |
| Public domain | `ARTIFACT_CDN_DOMAIN` | `:domain` | `cdn_domain` |
| Path prefix | `ARTIFACT_CDN_PATH_PREFIX` | `:path_prefix` | `cdn_path_prefix` |
| Public base URL override | `ARTIFACT_CDN_PUBLIC_BASE_URL` | `:public_base_url` | `cdn_public_base_url` |
| R2 account id | `ARTIFACT_CDN_R2_ACCOUNT_ID` | `:r2_account_id` | `cdn_r2_account_id` |
| R2 access key | `ARTIFACT_CDN_R2_ACCESS_KEY_ID` | `:r2_access_key_id` | `cdn_r2_access_key_id` |
| R2 secret | `ARTIFACT_CDN_R2_SECRET_ACCESS_KEY` | `:r2_secret_access_key` | `cdn_r2_secret_access_key` |
| R2 bucket | `ARTIFACT_CDN_R2_BUCKET` | `:r2_bucket` | `cdn_r2_bucket` |
| R2 endpoint | `ARTIFACT_CDN_R2_ENDPOINT` | `:r2_endpoint` | `cdn_r2_endpoint` |
| R2 region | `ARTIFACT_CDN_R2_REGION` | `:r2_region` | `cdn_r2_region` |
| Cloudflare zone | `ARTIFACT_CDN_CLOUDFLARE_ZONE_ID` | `:cloudflare_zone_id` | `cdn_cloudflare_zone_id` |
| Cloudflare token | `ARTIFACT_CDN_CLOUDFLARE_API_TOKEN` | `:cloudflare_api_token` | `cdn_cloudflare_api_token` |

`r2_endpoint` defaults to `https://{r2_account_id}.r2.cloudflarestorage.com` when
account id is set. `r2_region` defaults to `auto`.

Example credentials YAML:

```yaml
recording_studio_artifacts:
  api_key: REPLACE_ME
  cdn:
    subdomain: artifacts
    domain: example.com
    path_prefix: recording_studio_artifacts
    # public_base_url: https://artifacts.example.com  # optional override
    r2_account_id: REPLACE_ME
    r2_access_key_id: REPLACE_ME
    r2_secret_access_key: REPLACE_ME
    r2_bucket: artifacts-prod
    r2_endpoint: # optional; derived from account id
    r2_region: auto
    cloudflare_zone_id: REPLACE_ME
    cloudflare_api_token: REPLACE_ME
```

Dummy / test apps can assign `config.cdn_storage = RecordingStudioArtifacts::Cdn::MemoryStorage.new`
(and the same object as `cdn_purger`) so publish is exercisable without real R2 keys.
`aws-sdk-s3` is a runtime dependency of this gem; hosts do not need to add it manually.

## Consumer service API

```ruby
# Create + enqueue upload job
result = RecordingStudioArtifacts.publish(
  body: html_or_json_or_yml,
  content_type: "text/html; charset=utf-8",
  format: "html", # optional; inferred from content_type
  source: { gem: "recording_studio_embeddable", external_id: embed.token },
  metadata: { title: "Partner embed" },
  synchronous: false # default: ActiveJob; true runs upload inline
)

if result.success?
  artifact = result.value[:artifact]
  public_url = result.value[:public_url]
  # => https://artifacts.example.com/recording_studio_artifacts/<uuid>
end

# Update body; same object key + public URL forever
RecordingStudioArtifacts.update(
  id: artifact.id,
  body: new_body,
  content_type: "text/html; charset=utf-8"
)

# Unpublish: delete R2 object, purge the public URL, destroy the Artifact row
RecordingStudioArtifacts.unpublish(id: artifact.id)
```

There is no model mixin in v1. Consumers keep their own records and store the
returned `artifact.id` / `public_url`.

### Unpublish / destroy semantics

`RecordingStudioArtifacts.unpublish(id:)` **destroys** the Artifact row after
deleting the R2 object and purging the public URL. There is no `unpublished`
status. Destroying an Artifact directly also deletes the R2 object (via a
`before_destroy` callback) when CDN storage is configured, so rows do not leave
silent orphans.

## Job / overwrite / purge / concurrency

`RecordingStudioArtifacts::PublishArtifactJob` uploads to R2 and, when
Cloudflare purge credentials are present, purges the public URL.

- Each publish/update bumps an integer `revision`. The job receives that revision
  and skips work when a newer revision has already been persisted.
- Publish serializes per artifact with a DB row lock (`with_lock`) so it works
  with any ActiveJob adapter.
- Once the R2 upload succeeds, the artifact is marked `published`. Purge failures
  are recorded on `purge_error` / `purged_at` and do **not** fail publish or cause
  a re-upload.
- Upload failures (including `LoadError`) mark the artifact `failed` so it cannot
  sit stuck in `uploading`.
- Missing artifact rows raise (`ActiveRecord::RecordNotFound`) so a job cannot
  silently leave work unfinished.
- The job sets `enqueue_after_transaction_commit = true`.

Overwrites always target the same key so partner bookmarks stay valid.

## Install

```bash
bundle add recording_studio_artifacts
bin/rails generate recording_studio_artifacts:install
bin/rails generate recording_studio_artifacts:migrations
bin/rails db:migrate
```

Then set `ARTIFACT_CDN_*` (or credentials). `aws-sdk-s3` comes with the gem.

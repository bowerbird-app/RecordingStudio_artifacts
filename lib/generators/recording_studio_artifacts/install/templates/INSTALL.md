RecordingStudioArtifacts install complete.

Next steps:

1. Review config/initializers/recording_studio_artifacts.rb and set CDN options (or `ARTIFACT_CDN_*` env / credentials).
2. Host owns Cloudflare R2 bucket + custom domain DNS. See the gem's `docs/CDN.md`.
3. `aws-sdk-s3` is a gem runtime dependency — no host Gemfile entry needed for R2 uploads.
4. Install migrations with `bin/rails generate recording_studio_artifacts:migrations`, then `bin/rails db:migrate`.
5. Publish via the service API only:
   `RecordingStudioArtifacts.publish(body:, content_type:)` /
   `RecordingStudioArtifacts.update(id:, body:, content_type:)` /
   `RecordingStudioArtifacts.unpublish(id:)`.
6. Mount routes are optional for this gem (CDN publish is service/job based).

Security: artifact public URLs are bearer URLs. Anyone with the UUID can fetch the object.
Do not publish protected or embargoed content. When published HTML may contain user content,
serve it from a separate domain — not a subdomain of the app's cookie domain.

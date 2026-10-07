# Recording Studio kit pin update

Copied addons now start on the Support host-kit floor.

- Gemspec: `add_dependency "recording_studio", "~> 4.2"`
- Dummy GitHub tags: Recording Studio `v4.2.2`, Accessible `v0.10.1`, Root Switchable `v0.5.1`, FlatPack `v0.1.196`
- Root and dummy Rails locks both `8.1.4`
- Authenticated dummy layout: `RecordingStudio::UsesDefaultLayout` plus FlatPack CSS/JS
- Hooks and BaseService come from core; do not copy them into a new addon
- Recordable declarations remain required
- Optional example mixin: `include RecordingStudio::Capabilities::Example.to(**opts)` wraps `RecordingStudio::Capabilities.include_for`. Installing the gem does not enable it globally.

# Recording Studio kit pin update

Copied addons now start on the Support host-kit floor.

- Gemspec: `add_dependency "recording_studio", ">= 7.0", "< 8.0"`
- Dummy GitHub tags: Recording Studio `v7.4.0`, Accessible `v0.45.1`, Trashable `v1.0.0` (`require: false`), Root Switchable `v0.16.0`, Metrics `v0.9.0`, Cache `v0.7.0`, FlatPack `v0.1.377`
- Root and dummy Rails locks both `8.1.4`
- Authenticated dummy layout: `recording_studio_layout` plus FlatPack CSS/JS
- Hooks and BaseService come from core; do not copy them into a new addon
- Recordable declarations remain required
- Optional example mixin: `include RecordingStudio::Capabilities::Example.to(**opts)` wraps `RecordingStudio::Capabilities.include_for`. Installing the gem does not enable it globally.

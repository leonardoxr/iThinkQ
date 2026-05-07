# ThinkQ

> Heavily WIP native macOS client for LG ThinQ devices.

ThinkQ is an experimental SwiftUI macOS app for viewing and controlling LG ThinQ devices through the ThinQ Connect API. It is built as a native desktop app with a full window, menu bar dashboard, onboarding, Keychain token storage, polling, live-event groundwork, and device-specific controls for common appliance families.

This project is not affiliated with, endorsed by, or supported by LG Electronics. ThinQ, LG, and related marks belong to their owners.

## Current Status

ThinkQ is early, public, and actively changing.

- Works with Personal Access Token authentication.
- Stores the token in macOS Keychain.
- Supports Brazil and other ThinQ country/region mappings.
- Discovers devices, profiles, status, and writable controls.
- Provides a native SwiftUI full-window app and menu bar experience.
- Uses smart caching/backoff to reduce ThinQ API calls.
- Includes MQTT live-event client plumbing, but HTTP polling remains the reliability baseline.

Expect rough edges. Device profile shapes vary by model, region, and firmware, so some controls may be hidden, mislabeled, or require more real-world fixtures.

## Screenshots

Screenshots are intentionally not committed yet because the UI is changing quickly. Public screenshots should avoid exposing personal device names, device IDs, rooms, tokens, or raw ThinQ payloads.

## Requirements

- macOS 15 or newer
- Xcode command line tools or Xcode with Swift 6 toolchain
- LG ThinQ Personal Access Token

## Getting A ThinQ Token

1. Open the LG ThinQ Personal Access Token portal: <https://connect-pat.lgthinq.com/tokens>
2. Sign in with the same LG account used by your ThinQ devices.
3. Create a Personal Access Token.
4. Open ThinkQ and paste the token during onboarding or in Settings.
5. Choose your country, then use **Test Token** before saving.

ThinkQ stores the token in Keychain under the app bundle identifier. It does not intentionally log tokens, raw MQTT payloads, or personal device data.

## Build

```sh
swift build
swift test
./script/build_app.sh
```

The app bundle is written to:

```text
dist/ThinkQ.app
```

To launch explicitly:

```sh
./script/build_and_run.sh run
```

## Release Packaging

```sh
./script/package_release.sh
```

This creates a zip under `dist/` from the locally built app bundle. Public releases are currently marked as prerelease/WIP and are not notarized.

## Architecture

- `App/` app entry point, scenes, commands, menu bar setup
- `Models/` ThinQ domain types, JSON wrappers, API errors, region mapping
- `Services/` HTTP client, profile parser, control validation, Keychain, MQTT, certificates
- `Stores/` observable app state, session, device refresh/cache/customization
- `Support/` logging, API references, display helpers, shared glass styling
- `Views/` SwiftUI windows, settings, onboarding, sidebar, device panels, menu bar UI

## Privacy And Safety

- Personal Access Token: Keychain only.
- Device cache: local Application Support cache for offline UI and API-call reduction.
- Logs: use `os.Logger` categories and avoid tokens/raw payloads.
- Controls: validate writable profile metadata before sending commands.
- Rate limits: backoff and cache reuse are used to avoid hammering LG APIs.

## Roadmap

- Improve real-device profile fixtures and decoding.
- Harden live MQTT reconnect/certificate handling.
- Expand bespoke panels for laundry, refrigerator, robot cleaner, air care, and kitchen devices.
- Add safer control previews and confirmations for higher-risk appliance actions.
- Improve localization and user-facing labels.
- Add notarized distribution once the app stabilizes.

## Contributing

Contributions are welcome, especially real-world profile/status fixture improvements with all personal identifiers removed. Please read [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md) first.

## License

MIT. See [LICENSE](LICENSE).

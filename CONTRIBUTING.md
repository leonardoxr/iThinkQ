# Contributing To ThinkQ

ThinkQ is heavily WIP, so small, well-scoped contributions are easiest to review.

## Good First Contributions

- Improve device profile parsing for a real LG model.
- Add sanitized fixtures for profile/status responses.
- Improve display labels for capabilities and enum values.
- Add tests for country mapping, API decoding, or control validation.
- Polish SwiftUI views without adding broad architectural churn.

## Privacy Rules

Do not commit:

- Personal Access Tokens
- Device IDs
- Home names, room names, addresses, emails, or account IDs
- Raw MQTT topics or payloads
- Client certificates, private keys, `.pem`, `.p12`, `.key`, or `.crt` files

When sharing fixtures, redact stable identifiers and keep only the minimum structure needed for tests.

## Local Checks

Run:

```sh
swift build
swift test
./script/build_app.sh
```

## Pull Requests

Please include:

- What changed
- Why it matters
- How it was tested
- Any device family or country/region affected

Mark risky control behavior clearly. Appliance controls should fail closed when profile metadata is missing or ambiguous.

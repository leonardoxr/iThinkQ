# Security Policy

ThinkQ is experimental and heavily WIP. Please treat security and privacy reports seriously, but expect fast-moving internals while the app stabilizes.

## Supported Versions

Only the latest `main` branch is currently supported.

## Reporting A Vulnerability

Please do not open a public issue containing secrets, device IDs, raw payloads, certificates, or reproducible private account data.

Use a private GitHub security advisory if available, or contact the repository maintainer privately.

## Sensitive Data Handling

ThinkQ is designed to:

- Store ThinQ Personal Access Tokens in macOS Keychain.
- Avoid logging tokens and raw personal device payloads.
- Keep generated MQTT private keys in memory and temporary files only.
- Cache device data locally to reduce LG API calls.

The local cache can contain device names, profile metadata, and status values. Do not share cache files in issues or pull requests.

## Scope

In scope:

- Token leakage
- Raw device data leakage
- Unsafe command execution paths
- Certificate/private-key handling
- Cache privacy issues
- Network/API request security

Out of scope for now:

- Missing notarization on WIP prerelease builds
- Cosmetic UI issues without privacy/security impact
- Attacks requiring full local account compromise

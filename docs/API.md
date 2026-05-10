# ThinQ API Notes

iThinkQ uses the ThinQ Connect API behavior documented by LG and observed in official/open SDKs.

Primary references:

- ThinQ Connect API portal: <https://smartsolution.developer.lge.com/en/apiManage/thinq_connect>
- Device profile API portal: <https://smartsolution.developer.lge.com/en/apiManage/device_profile>
- Personal Access Token portal: <https://connect-pat.lgthinq.com/tokens>

## Authentication

The app uses Personal Access Token authentication. Tokens are supplied by the user during onboarding or Settings and stored in macOS Keychain.

## Regions

Countries map to ThinQ region domains:

- `aic`
- `kic`
- `eic`

The app derives the region from the selected country before making API requests.

## Request Headers

ThinQ API requests include:

- `Authorization: Bearer <token>` when required
- `x-country`
- `x-message-id`
- `x-client-id`
- `x-api-key`
- `x-service-phase: OP`

Do not log full requests, tokens, or raw device payloads.

# Releasing

Pushing a `v*` tag triggers `.github/workflows/release.yml`, which builds a DMG
and attaches it to the matching GitHub Release (creating it if needed).

```bash
# bump the version in scripts/AppInfo.plist first, then:
git tag v0.2.0 && git push origin v0.2.0   # push to the GitHub remote
```

## Signed + notarized releases (optional)

Without secrets, CI produces an ad-hoc-signed DMG (users must clear quarantine).
To ship a signed, notarized DMG automatically, add these repository secrets
(Settings → Secrets and variables → Actions):

| Secret | What it is |
|---|---|
| `MACOS_CERT_P12` | base64 of your exported "Developer ID Application" .p12 |
| `MACOS_CERT_PASSWORD` | password for that .p12 |
| `MACOS_SIGN_IDENTITY` | e.g. `Developer ID Application: Your Name (TEAMID)` |
| `AC_API_KEY_P8` | base64 of an App Store Connect API key (.p8) |
| `AC_KEY_ID` | the API key's Key ID |
| `AC_ISSUER_ID` | the API key's Issuer ID |

Export the cert: `security export` / Keychain Access → export the Developer ID
Application identity as .p12, then `base64 -i cert.p12 | pbcopy`.

Create the API key at App Store Connect → Users and Access → Integrations → keys.

Locally, you can still run `./scripts/release.sh` which uses a stored notarytool
keychain profile instead of API-key secrets.

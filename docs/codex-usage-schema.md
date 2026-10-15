# GET https://chatgpt.com/backend-api/wham/usage - response schema (Codex / ChatGPT plan)

Observed 2026-10-14, HTTP 200, plan_type `team`. Undocumented endpoint; treat every key as optional and decode defensively.
Raw sample (contains email/IDs, gitignored): `scripts/codex-usage-sample.json`.

## Credentials: file `~/.codex/auth.json` (honour `$CODEX_HOME` if set, else `~/.codex`)
Plain JSON file (mode 600), not Keychain. Never log any token.

| key | type | notes |
|---|---|---|
| `auth_mode` | string | `"chatgpt"` for ChatGPT login (API-key mode has no usage windows) |
| `OPENAI_API_KEY` | string or null | null for ChatGPT login |
| `tokens.access_token` | string (JWT) | Bearer token |
| `tokens.account_id` | string | sent as `ChatGPT-Account-Id` header |
| `tokens.id_token`, `tokens.refresh_token` | string | not used by the app |
| `last_refresh` | string (ISO 8601) | not used |

Codex CLI refreshes the token and rewrites the file itself. The app is read-only: re-read the file before each request; on 401/403 re-read once and retry once; then report "Run codex to re-authenticate". Never refresh or write the file.

## Request headers
`Authorization: Bearer <access_token>`, `ChatGPT-Account-Id: <account_id>`, `Accept: application/json`.

## Response
| key | type | notes |
|---|---|---|
| `plan_type` | string | e.g. `team`, `plus`, `pro` |
| `rate_limit` | object or null | see below |
| `rate_limit.allowed`, `rate_limit.limit_reached` | bool | |
| `rate_limit.primary_window` | object or null | **5-hour window** (`limit_window_seconds` = 18000) |
| `rate_limit.secondary_window` | object or null | **weekly window** (`limit_window_seconds` = 604800) |
| `code_review_rate_limit`, `additional_rate_limits`, `rate_limit_reached_type`, `promo` | null (observed) | ignore |
| `spend_control.individual_limit` | object | workspace credit cap; not shown in v1 |
| `user_id`, `account_id`, `email` | string | PII: never log |

Window object:
| field | type | notes |
|---|---|---|
| `used_percent` | int | **0-100** (normalise to 0-1 like the Claude side) |
| `limit_window_seconds` | int | 18000 / 604800 |
| `reset_after_seconds` | int | seconds from response time |
| `reset_at` | int | **Unix epoch seconds** (preferred for resetsAt) |

Mapping: primary = 5-hour, secondary = weekly. There is no per-model window.

## Redacted sample
```json
{"plan_type":"team","rate_limit":{"allowed":true,"limit_reached":false,
 "primary_window":{"used_percent":1,"limit_window_seconds":18000,"reset_after_seconds":17934,"reset_at":1792025805},
 "secondary_window":{"used_percent":0,"limit_window_seconds":604800,"reset_after_seconds":604734,"reset_at":1792612605}},
 "code_review_rate_limit":null,"additional_rate_limits":null,"rate_limit_reached_type":null}
```

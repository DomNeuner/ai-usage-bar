# GET https://api.anthropic.com/api/oauth/usage - response schema

Observed 2026-10-14, HTTP 200. Headers: `Authorization: Bearer <accessToken>`, `anthropic-beta: oauth-2025-04-20`.
Undocumented endpoint; treat every key as optional and decode defensively.

## Credentials (Keychain item "Claude Code-credentials")
JSON: `claudeAiOauth.accessToken` (string, `sk-ant-oat...`), `claudeAiOauth.expiresAt` = **epoch milliseconds** (int, e.g. `1792033877009`). Never log the token.

## Utilization scale
**0-100 percent** (e.g. `6.0` = 6%), NOT 0-1. Doubles in the legacy window objects, ints in `limits[].percent`.

## Window objects (top-level keys)
Shape of `five_hour` / `seven_day`:

| field | type | notes |
|---|---|---|
| `utilization` | number | 0-100 |
| `resets_at` | string | ISO 8601 with fractional seconds (microseconds) and `+00:00` offset, e.g. `2026-10-14T21:10:00.457824+00:00`. Swift ISO8601DateFormatter with `.withFractionalSeconds` handles ms but may fail on 6 digits; trim/parse manually. |
| `limit_dollars`, `used_dollars`, `remaining_dollars`, `locked_reason` | null (observed) | |

- **5-hour window:** `five_hour`
- **7-day window:** `seven_day`
- Model-specific legacy keys: `seven_day_opus`, `seven_day_sonnet` (both `null` in sample), also `seven_day_oauth_apps`, `seven_day_cowork`, `seven_day_omelette` (null).
- **Fable: there is NO top-level `seven_day_fable` key.** Fable appears only inside `limits[]` as an entry with `kind: "weekly_scoped"` and `scope.model.display_name == "Fable"` (`scope.model.id` is null). Match on display_name.

## `limits[]` (preferred, generic list)
Each item: `kind` (string: `session`, `weekly_all`, `weekly_scoped`), `group` (`session`|`weekly`), `percent` (int 0-100), `severity` (string, `normal` observed), `resets_at` (same ISO format; the Fable entry used `2026-10-17T06:00:00+00:00` with no fractional part, so support both), `scope` (null, or `{"model":{"id":null,"display_name":"Fable"},"surface":null}`), `is_active` (bool).

Mapping: `session` = 5-hour, `weekly_all` = 7-day, `weekly_scoped` + Fable = Fable weekly.

## Other keys
`extra_usage` (object, fields mostly null), `spend` (object), `member_dashboard_available` (bool), `seven_day_breakdown` (null), `weekly_scoped_shares` (array of `{limit_index, used_percent_of_weekly, allowance_percent_of_weekly}`), plus many obfuscated always-null keys: `tangelo`, `iguana_necktie`, `omelette_promotional`, `nimbus_quill`, `cinder_cove`, `copper_kite`, `brass_thimble`, `harbor_lantern`, `wattle_ember`, `amber_ladder`, `amber_cistern`, `juniper_tide`, `cedar_ember`, `amber_gauge`. Ignore these.

## Nullable keys (null in sample)
`seven_day_oauth_apps`, `seven_day_opus`, `seven_day_sonnet`, `seven_day_cowork`, `seven_day_omelette`, all obfuscated keys above, `seven_day_breakdown`; inside windows: `limit_dollars`, `used_dollars`, `remaining_dollars`, `locked_reason`; `limits[].scope` (null for non-scoped). `five_hour`/`seven_day` were non-null but should be treated as nullable.

## Sample (no secrets present)
```json
{"five_hour":{"utilization":6.0,"resets_at":"2026-10-14T21:10:00.457824+00:00","limit_dollars":null,"used_dollars":null,"remaining_dollars":null,"locked_reason":null},"seven_day":{"utilization":3.0,"resets_at":"2026-10-17T06:00:00.457845+00:00","limit_dollars":null,"used_dollars":null,"remaining_dollars":null,"locked_reason":null},"seven_day_oauth_apps":null,"seven_day_opus":null,"seven_day_sonnet":null,"seven_day_cowork":null,"seven_day_omelette":null,"tangelo":null,"extra_usage":{"is_enabled":false,"monthly_limit":null,"used_credits":null,"utilization":null,"currency":null,"decimal_places":null,"disabled_reason":null,"user_disabled":true,"spend_limit_reached":false,"credits_ever_enabled":true,"daily":null,"weekly":null},"limits":[{"kind":"session","group":"session","percent":6,"severity":"normal","resets_at":"2026-10-14T21:10:00.457824+00:00","scope":null,"is_active":true},{"kind":"weekly_all","group":"weekly","percent":3,"severity":"normal","resets_at":"2026-10-17T06:00:00.457845+00:00","scope":null,"is_active":false},{"kind":"weekly_scoped","group":"weekly","percent":0,"severity":"normal","resets_at":"2026-10-17T06:00:00+00:00","scope":{"model":{"id":null,"display_name":"Fable"},"surface":null},"is_active":false}],"spend":{"used":{"amount_minor":0,"currency":"USD","exponent":2},"limit":null,"percent":0,"severity":"normal","enabled":false,"disabled_reason":null,"cap":null,"balance":null,"auto_reload":null,"disclaimer":"...","can_purchase_credits":false,"can_toggle":false},"member_dashboard_available":false,"seven_day_breakdown":null,"weekly_scoped_shares":[{"limit_index":2,"used_percent_of_weekly":0,"allowance_percent_of_weekly":50}]}
```
(Other obfuscated null keys elided.)

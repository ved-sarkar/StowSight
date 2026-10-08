# StowSight — live integration plan

Status: design only. No credentials, model setup, inference calls, media uploads, camera access, mobile project provisioning or deployments were performed.

## Proposed product flow

Phone video selection or camera recording → local clip preview and upload consent → bounded recognition request → editable observations with frame/time evidence → explicit add/match/exclude review → local inventory commit. A later video starts another review against saved inventory. Unseen objects are retained unless the user explicitly deletes them.

## Decisions needed before live work

| Decision | Proposed starting point | Still needed |
| --- | --- | --- |
| Phone platform | Native iOS SwiftUI shell, sharing the Foundation review/store module | Confirm iOS-first and minimum supported OS; add an iOS project and simulator/device validation |
| Provider and model | Gemini API behind an authenticated backend; no secret bundled in the phone app | User-owned project, chosen supported video-capable model, approved budget/quota and permitted region/data policy |
| Media permission | Start with user-selected clips; camera capture later, at an explicit tap | Permission to implement real import/capture; user-selected test footage; camera usage text. Leave microphone off unless audio is explicitly needed |
| Upload scope | Preview the exact clip and obtain per-scan consent; strip audio and unnecessary metadata as a product policy | Approve sending selected footage to the provider and choose retention/deletion behavior |
| Identity matching | Suggestions only, with side-by-side evidence; human confirms every match | Decide whether item photos/crops may be stored locally and whether prior inventory context may be sent |
| Cost and retention | Short clips, bounded requests, server rate limits, no background scans | A concrete spend ceiling and cleanup/retry policy before paid calls |

Google's official guidance recommends a backend proxy for production clients so the Gemini key stays out of mobile code. That supports the backend proposal above; no backend exists in this prototype. [Gemini API key security](https://ai.google.dev/gemini-api/docs/api-key)

## Adapter boundary and milestones

1. **Local iOS intake.** Introduce a validated `ClipInput` carrying a local selected asset, duration and MIME type instead of today's `DemoClip` enum. Show a playable preview, cancellation and a clear upload consent boundary. Test denied access, unsupported formats, oversized/long clips and app backgrounding. Keep the existing mock adapter available.
2. **Backend recognition.** Authenticate app requests, enforce byte/duration/request limits and hold provider secrets server-side. Use the provider's current video input route. The official video guide supports inline video and uploaded file references; uploaded video may need processing before inference. Validate the selected API/model's limits at implementation time because documentation routes and limits evolve. [Video understanding](https://ai.google.dev/gemini-api/docs/video-understanding)
3. **Validated proposal contract.** Request a JSON schema containing an observation ID, proposed name, visible features, timestamps/evidence references, uncertainty, and optional candidate match IDs. Generate/validate IDs locally. Bound strings, counts, numbers and timestamps; reject malformed, duplicate, missing or out-of-range data. Structured output constrains format but must not be treated as proof that an observation or identity match is correct. Keep the current review transaction as the only write path. [Structured outputs](https://ai.google.dev/gemini-api/docs/structured-output)
4. **Cancellation and cleanup.** Implement upload/inference timeouts, bounded backoff and idempotent request identifiers. Discard late responses after cancellation. Delete remote uploaded files after success/cancel/failure where possible and queue cleanup retries. Google's Files documentation describes automatic expiry after 48 hours and an explicit deletion endpoint; this is not a guarantee about all downstream provider data handling. [Files API](https://ai.google.dev/gemini-api/docs/files)
5. **Evidence-based reconciliation.** Add crop/time comparison, candidate matches across different names, and explicit conflict resolution. Never use confidence alone to auto-merge or remove an item. Evaluate with consented representative clips and known ground truth before claiming recognition quality.
6. **Shipping work.** Version/migrate persistence, persist or explicitly discard drafts on interruption, add multi-process protection if needed, test accessibility and small-screen layouts, add iOS UI tests and privacy disclosures. Keep offline demo/test fixtures separate from live mode.

Official documentation reviewed on 2026-10-08. The chosen model, pricing, API method, quotas and provider data terms must be rechecked when live integration is authorized. No specific model version is embedded or provisioned here.

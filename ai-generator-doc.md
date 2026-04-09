# AI-powered Landing Page Builder — Technical Documentation

Last updated: 2026-04-09

## Purpose

This document describes the AI-powered landing page builder in the Tarmeez platform. It is intended for engineers who will maintain, extend, or operate the system. It covers the database models, server architecture, AI orchestration, queue/worker behavior, and front-end integration (generation UI, preview, and page builder). Where useful, file references point to the current implementation.

## Contents

- Overview
- Data model (database)
- Server side (controllers, services, workers)
- AI orchestration and provider behavior
- Normalization & validation
- Refinement (edit) flows
- Front-end (UI, editor, preview)
- APIs and client hooks (RTK Query)
- Operational notes, environment variables and metrics
- Troubleshooting & recommended improvements

## Overview

The AI page builder allows merchants to create a landing page from a short prompt (optionally tied to a product). Key goals:

- Produce a valid, structured landing-page JSON (sections + metadata).
- Validate and normalize AI output before persisting or publishing.
- Persist generation lifecycle data (queued → processing → completed/failed).
- Provide a chat-like refinement UI allowing merchants to refine whole-page, section, or field-level changes.
- Create a Page record from validated AI content and make it editable in the visual page builder.

High-level flow (user → system)

1. Merchant enters prompt in the AIGenerator UI and submits.
2. Client calls POST /merchant/landing-page/generate → LandingPageService.createGeneration.
3. LandingPageGeneration record is created (status=PENDING) and a BullMQ job is enqueued.
4. Worker (LandingPageProcessor) picks the job, updates status → PROCESSING, and delegates to LandingPageOrchestrator.
5. Orchestrator performs 3 AI calls (analysis+plan, light batch, heavy batch) via AIProvider (GeminiProvider). Output combined and normalized.
6. If normalization succeeds, a new `Page` (type=LANDING) is created, and the LandingPageGeneration record is updated with `content` and `pageId` and status COMPLETED.
7. Client polls `GET /merchant/landing-page/generations/:id` to display progress and final links (preview / edit).

File references (key code locations)

- Server landing-page flow: [server/src/landing-page/landing-page.service.ts](server/src/landing-page/landing-page.service.ts)
- Worker: [server/src/landing-page/landing-page.processor.ts](server/src/landing-page/landing-page.processor.ts)
- Orchestrator: [server/src/landing-page/landing-page.orchestrator.ts](server/src/landing-page/landing-page.orchestrator.ts)
- Gemini provider (LLM integration): [server/src/landing-page/providers/gemini.provider.ts](server/src/landing-page/providers/gemini.provider.ts)
- Normalization (server): [server/src/landing-page/normalization.service.ts](server/src/landing-page/normalization.service.ts)
- Refiner: [server/src/landing-page/landing-page.refiner.ts](server/src/landing-page/landing-page.refiner.ts)
- Controller & routes: [server/src/landing-page/landing-page.controller.ts](server/src/landing-page/landing-page.controller.ts)
- Prisma schema: [server/prisma/schema.prisma](server/prisma/schema.prisma)
- Client generator UI: [client/components/pages/merchant/AIGenerator.tsx](client/components/pages/merchant/AIGenerator.tsx)
- Client generator workspace (chat + preview): [client/components/ai-generator/GeneratorWorkspace.tsx](client/components/ai-generator/GeneratorWorkspace.tsx)
- Generator context/state: [client/components/ai-generator/GeneratorContext.tsx](client/components/ai-generator/GeneratorContext.tsx)
- Preview rendering: [client/lib/ai-generator/preview-renderer.ts](client/lib/ai-generator/preview-renderer.ts)
- AI schemas & normalization (client): [client/lib/ai-generator](client/lib/ai-generator)
- RTK Query endpoints (client): [client/lib/services/landingPageApi.ts](client/lib/services/landingPageApi.ts)

## Data model (database)

The DB uses Prisma. Two important models for AI pages are `Page` and `LandingPageGeneration`.

1. Page (canonical public page table)

- Location: [server/prisma/schema.prisma](server/prisma/schema.prisma) — `model Page`.
- Important fields used by AI pages:
  - `id`, `storeId`: multi-tenant association. All queries must scope by `storeId`.
  - `type`: LANDING / CUSTOM / POLICY (AI pages use `LANDING`).
  - `content` (Json): canonical content saved for preview + editor. For AI pages `content` holds the validated `LandingPageContent` (sections + metadata) or `puckData` for Puck v2 layout.
  - `chatHistory` (Json?): persistent conversation messages used for refinement.
  - `metadata` (Json?): contains `{ generationId, prompt, language, tone }` for traceability.

2. LandingPageGeneration — generation lifecycle

- Location: `LandingPageGeneration` model in Prisma schema.
- Purpose: track the prompt, language, tone, status, normalized content, error messages, retry count, and linked page when creation succeeds.
- Fields (summary):
  - `id`, `storeId`, `productId?` — provenance/association
  - `status: GenerationStatus` — enum (PENDING, PROCESSING, COMPLETED, FAILED)
  - `prompt`, `language`, `tone`
  - `content` (Json?) — normalized AI output persisted for debugging/inspection
  - `errorMessage` (string) — when status=FAILED
  - `pageId?` (unique) — created Page reference on success
  - `retryCount`, `createdAt`, `updatedAt`

Indexes & constraints

- Migration adds indexes on `storeId` and `status`, a unique index on `pageId` (because a generation can link to one page) and a foreign key to `Store` with cascade deletes.

## Server side architecture

Landing-page server components and responsibilities:

- LandingPageController — HTTP endpoints (generate, list, get, retry, refine, ai-pages, get chat)
  File: [server/src/landing-page/landing-page.controller.ts](server/src/landing-page/landing-page.controller.ts)

- LandingPageService — application logic invoked by controllers.
  Responsibilities: validate input, create `LandingPageGeneration` record (status=PENDING), enqueue a BullMQ job, expose listing/get/retry/refine APIs, and `listAIPages`.
  File: [server/src/landing-page/landing-page.service.ts](server/src/landing-page/landing-page.service.ts)

- LandingPageProcessor (Worker) — picks jobs from `landing-page-generation` queue and executes full generation.
  Responsibilities:
  - Update generation status to PROCESSING.
  - Load short product context when `productId` exists.
  - Call LandingPageOrchestrator.generate (AI orchestration + normalization).
  - Create the `Page` entity (slug generation, chatHistory seed, metadata) and mark the generation COMPLETED with `pageId`.
  - On error mark generation FAILED with `errorMessage` and increment retryCount (BullMQ handles further retries).
    File: [server/src/landing-page/landing-page.processor.ts](server/src/landing-page/landing-page.processor.ts)

- LandingPageOrchestrator — single place controlling the AI call ordering and metrics.
  - Reduces per-section calls to a consistent 3-call pattern: analyze+plan, light batch, heavy batch.
  - Returns normalized output + generation metrics.
    File: [server/src/landing-page/landing-page.orchestrator.ts](server/src/landing-page/landing-page.orchestrator.ts)

- AI Provider abstraction + implementation(s) — the system supports an AI provider interface and currently implements GeminiProvider.
  - `GeminiProvider` wraps the Google Generative AI client, provides retries and fallback models, and parsing helpers to extract JSON from responses.
    File: [server/src/landing-page/providers/gemini.provider.ts](server/src/landing-page/providers/gemini.provider.ts)

- NormalizationService — validates each section and returns a canonical `sections` array and `metadata`. This runs on the server before creating the final `Page`.
  File: [server/src/landing-page/normalization.service.ts](server/src/landing-page/normalization.service.ts)

- LandingPageRefiner — used for synchronous refinement calls (full/section/field). It calls the AI provider to get a delta and applies either a FULL replace or a PARTIAL patch merge.
  File: [server/src/landing-page/landing-page.refiner.ts](server/src/landing-page/landing-page.refiner.ts)

## AI orchestration and provider behavior

Orchestrator pattern (single source-of-truth ordering):

1. Call 1 — Analysis + Plan (combined)
   - Produces page DNA (primaryHook, brandPersonality, keyBenefits) and a `plan` (ordered selectedSections). The planner enforces mandatory sections and fills up to a minimum number of sections.
2. Split sections into `light` and `heavy` based on complexity.
3. Call 2 — Generate Light Sections (single batch)
4. Build a compact `lightContext` (short summary of generated light sections) to avoid resending heavy content.
5. Call 3 — Generate Heavy Sections (single batch) with `lightContext` for coherence.
6. Combine light + heavy sections, wrap `metadata`, and pass to NormalizationService.

Why 3 calls? avoids N+2 calls (N = sections). It reduces total LLM calls and latency while keeping per-call token budgets manageable.

GeminiProvider specifics

- Uses GoogleGenerativeAI client. Key behaviors:
  - `callWithRetry` implements exponential retries for transient faults (503/429) and steps through fallback models if primary fails.
  - `callGemini` composes system + user prompts and asks for JSON-only responses (responseMimeType: 'application/json').
  - `parseJSON` / parse fallbacks attempt to strip fences or extract first JSON object to be resilient to noisy responses.

Environment variables that control provider behavior:

- `GEMINI_API_KEY`
- `GEMINI_PRIMARY_MODEL` (default: gemini-2.5-flash)
- `GEMINI_FALLBACK_MODEL_1`, `GEMINI_FALLBACK_MODEL_2`

## Normalization & validation

Normalization is performed both on the client and server to ensure consistent behavior.

Server normalization (source of truth):

- Validates required fields per section type (hero requires headline/subheadline/ctaText, features requires min 2 items, etc.).
- Deduplicates multiple occurrences of the same section type (keep first), sorts sections by canonical order, and builds `metadata` defaults (language/tone).
- Returns `errors` array and `warnings` array. If no valid sections remain, the generation fails and an error is surfaced.
  File: [server/src/landing-page/normalization.service.ts](server/src/landing-page/normalization.service.ts)

Client normalization: [client/lib/ai-generator/normalization.ts](client/lib/ai-generator/normalization.ts) mirrors server logic and is used to provide immediate validation and preview in the workspace.

## Refinement (edit) flows

Merchants can request refinements after a page is generated using a chat-style UI.

Refinement scopes supported:

- `full` — surgical full-page refine. AI may respond with `PARTIAL` (a delta with patches) or `FULL` (fullContent replace). The refiner applies patches or replaces content and runs normalization when applying full replacements.
- `section` — the AI returns a JSON object representing the updated section; the refiner merges it.
- `field` — a single field value update; parsed and merged.

Flow: client calls POST `/merchant/landing-page/:pageId/refine` with `RefinePageDto` containing `instruction`, `scope`, `currentContent`, and optional `conversationHistory`. LandingPageRefiner handles the request synchronously and returns a `RefineResult` including `updatedContent`.

## Front-end architecture

Key components and responsibilities:

- `AIGenerator` page (merchant UI)
  - File: [client/components/pages/merchant/AIGenerator.tsx](client/components/pages/merchant/AIGenerator.tsx)
  - Renders prompt form, language/tone pickers, optional product association, and calls `useGenerateMutation()`.
  - When a generation is started it stores `activeGenerationId` and shows `GenerationTracker` which polls `useGetGenerationQuery`.

- Client API (RTK Query)
  - `client/lib/services/landingPageApi.ts` exports hooks: `useGenerateMutation`, `useGetGenerationQuery`, `useRetryGenerationMutation`, `useRefinePageMutation`, `useListAIPagesQuery`, `useGetChatHistoryQuery`.
  - `client/lib/services/pagesApi.ts` exposes `useGetPageQuery` and page create/update endpoints used by the page editor.

- Generator Workspace (chat + preview)
  - `client/components/ai-generator/GeneratorWorkspace.tsx` composes `GeneratorProvider` and the `ChatPanel` + `PreviewPanel`.
  - `GeneratorContext` (`client/components/ai-generator/GeneratorContext.tsx`) keeps the conversation state, current page content, `phase` (`prompt | generating | workspace`), `pageId`, sessionStorage persistence (`ai-generator-v1`), and a ref to the preview iframe.
  - PreviewPanel uses `generatePreviewHtml` to produce a self-contained HTML `srcDoc` for an iframe so the merchant gets immediate visual feedback.
  - `PreviewPanel` overlays generating/refining states and provides 'Open in editor' link once a `pageId` exists.

- Visual Page Builder (Puck)
  - Editor: [client/lib/page-builder/editor/PageEditor.tsx](client/lib/page-builder/editor/PageEditor.tsx)
  - Puck config / components: [client/lib/page-builder/puck.config.tsx](client/lib/page-builder/puck.config.tsx)
  - Page content shapes: the system supports two shapes:
    1. `LandingPageContent` (sections: []) produced by AI (used for preview and saved in `page.content` for LANDING pages),
    2. `puckData` shape used by Puck v2 editor (for custom pages and editable assets).
  - PageEditor autosave: changes in Puck are auto-saved after a debounce (30s) via `updatePage` mutation (`pagesApi.updatePage`). The PageEditor validates content version fields and enforces slug sanitization and publish rules.

How the client links generation → editor

- After generator completes, `LandingPageProcessor` creates a `Page` and the generation record contains `pageId`.
- `GenerationTracker` resolves the `pageId` and renders links:
  - Preview URL: `${NEXT_PUBLIC_STORE_BASE_URL}/store/${storeSlug}/p/${page.slug}`
  - Editor URL: `/merchant/page-builder?pageId=${pageId}` (opens PageEditor and loads page content into Puck if needed).

## APIs (summary)

Server endpoints (merchant-guard protected):

- POST /merchant/landing-page/generate
  - Body: { prompt, productId?, language?, tone? }
  - Creates `LandingPageGeneration` and enqueues generation job.

- GET /merchant/landing-page/generations
  - Lists recent generations for the merchant's store.

- GET /merchant/landing-page/generations/:id
  - Returns generation detail and status. Client polls this to track progress.

- POST /merchant/landing-page/generations/:id/retry
  - Retry a failed generation. Only allowed if generation.status === FAILED.

- POST /merchant/landing-page/:pageId/refine
  - Body: `RefinePageDto` — synchronous refine request (full/section/field).

- GET /merchant/landing-page/ai-pages
  - Lists pages that have `metadata` (AI pages) for quick access.

Client RTK Query hooks

- `useGenerateMutation`, `useGetGenerationQuery`, `useRetryGenerationMutation`, `useRefinePageMutation`, `useListAIPagesQuery`, `useGetChatHistoryQuery`.
  File: [client/lib/services/landingPageApi.ts](client/lib/services/landingPageApi.ts)

## Queue / Worker / Retry behavior

- The service enqueues a BullMQ job named `generate` in queue `landing-page-generation` with options:
  - attempts: 2
  - backoff: exponential (delay 30000ms initial)
  - removeOnComplete: true
  - removeOnFail: false
- Worker updates generation status to PROCESSING, executes orchestrator.generate, persists output, and sets status to COMPLETED or FAILED.
- The provider (`GeminiProvider.callWithRetry`) also implements its own retry semantics for LLM transient errors (503/429) and executes a fallback chain of models.

## Security, multi-tenancy and validation

- MerchantGuard ensures `req.activeStore.id` is available in controller requests.
- All service DB queries check `storeId` (see PagesService.getPage, LandingPageService.getGeneration and others).
- LandingPageService validates `productId` ownership before accepting a generation tied to a product.

## Operational notes & env vars

- Primary envs:
  - `GEMINI_API_KEY` — required for AI provider
  - `GEMINI_PRIMARY_MODEL` / `GEMINI_FALLBACK_MODEL_1|2` — model names
  - BullMQ / Redis connection envs used by the job queue

- Metrics & logs:
  - Orchestrator emits metrics (totalCalls, tokenEstimate, durationMs, sections counts).
  - LandingPageProcessor logs start/finish durations and normalization warnings.
  - Keep an eye on normalization warnings — they indicate dropped sections or mis-shaped AI output.

## Testing & local developer commands

- There are helper test scripts in `server/src/landing-page/test-generation.ts` and `test-refine.ts` to run generation/refine flows locally. Example:

```bash
# from server/ folder
npx ts-node -r tsconfig-paths/register src/landing-page/test-generation.ts
```

## Best practices & recommended improvements

- Section-level checkpointing: persist partial sections as they are generated so a failure in one section does not require full re-generation.
- Streaming generation (or returning progressive previews) would improve merchant perceived latency for long pages.
- Instrument per-section token usage and error reasons to better identify brittle prompt templates.
- Add rate limiting / per-store quotas to protect LLM costs and platform stability.
- Consider abstracting `AIProvider` to add alternative LLMs or internal caching layers.

## Troubleshooting common failures

- Normalization fails with "Missing sections array" — the provider returned a malformed shape; check logs in worker and the raw `LandingPageGeneration.content` to inspect AI output.
- Parsing errors from provider — GeminiProvider.parseJSON applies resilient extraction, but some responses still fail. Review model prompt and increase `maxOutputTokens` conservatively if truncation occurs.
- Too many retries / expensive costs — examine orchestrator metrics (totalCalls, token estimates) and consider breaking heavy sections into smaller prompts or moving large assets off-model.

## Appendix: Quick links

- Landing page server module: [server/src/landing-page](server/src/landing-page)
- Client AI generator: [client/components/ai-generator](client/components/ai-generator)
- Client generator page: [client/components/pages/merchant/AIGenerator.tsx](client/components/pages/merchant/AIGenerator.tsx)
- Client preview/renderer: [client/lib/ai-generator/preview-renderer.ts](client/lib/ai-generator/preview-renderer.ts)
- Puck editor config: [client/lib/page-builder/puck.config.tsx](client/lib/page-builder/puck.config.tsx)

If you want, I can:

- add sequence diagrams (mermaid) for the generation flow,
- extract and publish the prompt templates used by the providers,
- add unit/integration test examples for normalization and refinement.

---

Generated by the engineering assistant. For edits or expansions, tell me which section to expand or what format you prefer (PDF, HTML, README-style, or inline code links).

# Amplissa Implementation Handoff

Use this brief to ask ChatGPT (or another engineer) to scaffold and deploy the Amplissa social network ("old-school Tumblr meets Facebook" with NSFW toggle). The repo currently only contains a placeholder `index.html`; the steps below describe what to build next.

## MVP goals
- Public landing page communicating the brand and community focus.
- Authenticated experience with profiles, post composer, timeline feed, comments, reactions, and follows.
- Per-user NSFW toggle enforced server-side and reflected in the UI (blur/click-to-reveal when off).
- Media uploads (images/video) stored in object storage; thumbnails and previews generated securely.
- Basic moderation: report flow, admin dashboard for reviewing flagged posts/users.

## Recommended stack
- **Frontend:** Next.js (App Router), TypeScript, Tailwind, React Query. Component library: Headless UI + Radix primitives; icon set like Heroicons.
- **Backend/API:** Next.js route handlers or Node/Express/NestJS; PostgreSQL via Prisma; Redis for sessions/queues; WebSockets or SSE for notifications; S3-compatible storage for media.
- **Infra:** Docker + docker-compose for local; deploy to a managed platform (Vercel for frontend, Fly.io/Render for API) with managed Postgres, Redis, and S3 bucket (e.g., Cloudflare R2). CI: GitHub Actions for lint/test/build.

## Domain model (initial)
- **User:** id, email, password hash or OAuth, displayName, avatarUrl, bio, nsfwEnabled (boolean), roles (user/mod/admin), createdAt/updatedAt.
- **Post:** id, authorId, body (text/HTML), media (array with type/url/thumb/nsfw flag), tags, visibility (public/followers), nsfw (boolean), createdAt/updatedAt.
- **Comment:** id, postId, authorId, body, createdAt/updatedAt, parentId (threading optional for MVP).
- **Follow:** followerId, followingId, createdAt.
- **Notification:** id, userId, type (follow/comment/mention), entityId, readAt.
- **Report:** id, targetType (user/post/comment), targetId, reporterId, reason, status, createdAt/updatedAt.

## Core features to request from ChatGPT
1. **Project bootstrap:** Create a monorepo or Next.js app with linting/formatting (ESLint, Prettier), commit hooks (lint-staged), and environment variable schema via Zod.
2. **Auth & profiles:** Email/password auth with bcrypt + JWT/session cookies; profile edit page; avatar upload to S3; age/NSFW consent gating during onboarding.
3. **Posts & media:** Rich-text/markdown editor; drag-drop media upload with server-side processing (image resize + video transcode placeholder); signed URLs; blur overlays for NSFW when user toggle off.
4. **Feed & social graph:** Following feed (chronological), explore feed by tags; follow/unfollow; mute/block; optimistic updates on actions.
5. **NSFW enforcement:** Store nsfwEnabled per user; filter queries on server; UI toggle persisted to user settings; blurred previews and "Tap to view" control when off.
6. **Moderation:** Report buttons on posts/profiles; admin review queue; soft-delete/shadow-ban; rate limiting; audit logs for admin actions.
7. **Notifications:** Real-time (WebSocket/SSE) plus email digests; settings for opt-outs.
8. **Deployment:** Dockerized app; `docker-compose` for local Postgres/Redis; production deploy scripts; seed script for demo data.

## Acceptance checklist
- Runs locally with `pnpm install` + `pnpm dev` (or `npm/yarn`), and `docker-compose up` for DB/Redis.
- All env vars documented in `.env.example` with safe defaults; secrets not committed.
- ESLint/Prettier/TypeScript pass; basic unit/integration tests for auth and feed endpoints.
- Media upload limited by size/type; NSFW toggle respected in all feed endpoints and UI states.
- README updated with setup, scripts, and deployment steps; CI passing.

## Optional enhancements to ask for after MVP
- Infinite scroll feed; bookmark/collections; search by tag/user; scheduled posts; profile badges; two-factor auth; content warnings per post; analytics dashboards; mobile app shell (React Native/Expo).

Use this doc as the prompt context when asking ChatGPT to generate the scaffolding and code. Provide the repository URL and clarify hosting targets so it can write tailored deployment files.

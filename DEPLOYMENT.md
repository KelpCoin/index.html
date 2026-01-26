# Deployment Guide: BrownEye Cortex + ComfyUI + MegaWrapper

This bootstrap guide wires the BrownEye Cortex API, ComfyUI GPU workers, and MegaWrapper dashboard into a single cinematic pipeline. Update hostnames and secrets to match your infrastructure.

## 1) Services to Provision

1. **BrownEye Cortex API**
   - Suggested base URL: `https://api.brandlycortex.local`
   - Responsibilities: scene ingest, storyboard orchestration, compositing, fan events.
2. **ComfyUI GPU Workers**
   - Suggested base URL: `https://comfyui.local`
   - Responsibilities: GPU render jobs, preview frames, prompt packs.
3. **MegaWrapper Dashboard**
   - Suggested base URL: `https://megawrapper.local`
   - Responsibilities: ops dashboard + public-facing slice.
4. **Stripe FanOps**
   - Checkout: payment mode for rerolls, VIP queues, and fan votes.
   - Webhooks: post event receipts to `/v1/fan/events`.

## 2) Configuration Files

* `pipeline.config.json` - canonical pipeline wiring, service endpoints, and fan actions.
* `index.html` - public dashboard shell (MegaWrapper UI slice).

## 3) Bootstrap API Stubs

Use this stub contract to get the control plane running quickly:

```
POST /v1/scenes
POST /v1/scenes/{scene_id}/storyboard
POST /v1/render/jobs
POST /v1/render/composite
POST /v1/fan/events
GET  /v1/dashboard/slice
```

## 4) Stripe Fan Interaction Flow

1. Create checkout session with metadata for the fan action.
2. Stripe webhook hits `/v1/fan/events`.
3. BrownEye Cortex updates `fan_interaction` on the pipeline and refreshes the MegaWrapper slice.

## 5) ComfyUI Installation Notes (High-Level)

1. Install ComfyUI on GPU workers.
2. Expose a render API endpoint (reverse proxy recommended).
3. Allow prompt packs + brand packs to be uploaded from BrownEye Cortex.

## 6) Validation Checklist

* Render job from ComfyUI returns preview frames.
* Compositor merges brand overlays + watermark.
* MegaWrapper public slice shows status and fan decisions.
* Stripe events register and update render priorities.

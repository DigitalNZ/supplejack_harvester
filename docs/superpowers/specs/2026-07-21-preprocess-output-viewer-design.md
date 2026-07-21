# View Pre-processing Data — Design

**Date:** 2026-07-21
**Branch:** ba/preprocessing-pipeline
**Story:** As Dan (PO), I want to inspect the data created from a pre-processing
block, so that I can be confident the pipeline is configured correctly.

## Background

A pre-processing block produces two kinds of data:

1. **Raw extracted data** — the block's own `ExtractionDefinition` creates
   `ExtractionJob`s viewable through the existing
   `pipelines/:id/harvest_definitions/:id/extraction_definitions/:id/extraction_jobs`
   routes. The shared `_definition_extraction_card` partial already links there,
   so this is already covered.
2. **Preprocessed output** — the transformed records the block feeds forward
   into the harvest. `TransformationWorker#feed_forward` writes them via
   `PreProcess::Output` to
   `extractions/<env>/preprocess/<pipeline_job_id>/<position>/…` in the standard
   `Extraction::Documents` on-disk layout. **No route, model read-side, or UI
   exists for this today.** This is what the story is about (confirmed with Ben).

## Scope

- **View-only.** No delete, cancel, or run actions.
- Entry point: the preprocess block's card on the pipeline page.
- Out of scope (flag to PO as separate tech-debt story): preprocess output
  folders are never cleaned up — nothing deletes
  `extractions/<env>/preprocess/<pipeline_job_id>/` when a pipeline job is
  destroyed.

## Design

### Routes & controller

```ruby
resources :harvest_definitions, only: %i[create update destroy] do
  resources :preprocess_outputs, only: %i[index show]   # new
  ...
end
```

New `PreprocessOutputsController`, shaped like `ExtractionJobsController`
(same `find_pipeline` / `find_harvest_definition` before-actions):

- **index** — lists this block's runs that have output on disk:
  `@pipeline.pipeline_jobs`, newest first, filtered to those where
  `PreProcess::Output` exists for this block's position. Kaminari-paginated.
- **show** — `:id` is the **pipeline job id**. Loads `PreProcess::Output` for
  `(pipeline_job.id, harvest_definition.position)` and pages documents exactly
  like the extraction viewer:
  `@documents = output.documents; @document = @documents[params[:page]]`.
  Finds the pipeline job through `@pipeline.pipeline_jobs` so a job belonging
  to another pipeline 404s.

Read-only by construction.

### Model — read side on `PreProcess::Output`

`PreProcess::Output` already owns the folder layout for writing; it gains the
read side so nothing else learns the path structure:

- `documents` → `Extraction::Documents.new(@folder)` — same layout as
  extraction folders, so paging works unchanged.
- `exists?` → whether any output pages have been written for this
  run + position.

### Views & navigation

- **Block card link:** in `_preprocess_definition.html.erb` (deliberately NOT
  in the shared partials, so enrichment blocks are untouched), a
  "Preprocessed data" link to the index — same visual pattern as the extraction
  card's jobs link.
- **`preprocess_outputs/index.html.erb`:** table of runs (run name, status from
  the block's harvest report, date, view link), modeled on the extraction-jobs
  index. Empty state: "This block has no preprocessed data yet — run the
  pipeline to generate some."
- **`preprocess_outputs/show.html.erb`:** slim version of
  `extraction_jobs/show` — header, total pages + pagination, and just the
  **Result** viewer (the existing `extraction-result-viewer` JS component,
  format JSON). No Request/Response tabs (the stored documents are synthetic:
  `url: nil, status: 200`), no action buttons. Keeps the >10 MB "too large to
  preview in the browser" guard.
- Breadcrumbs wired into the existing breadcrumb config; new `en.yml` strings.

### Edge cases

- **Run still in progress:** pages appear as transformation workers write them;
  whatever exists is viewable. The index only lists runs once at least one page
  exists.
- **Page param out of range / missing document:** friendly "page could not be
  found" style message, as the extraction viewer does.
- **Multiple preprocess blocks:** everything is keyed by the block's
  `position`, so each block's card shows only its own output.

### Testing

- Request specs for index and show (auth, only-runs-with-output filtering,
  document paging, other-pipeline 404), following the existing
  `extraction_jobs` request-spec patterns; write real files to the test
  extraction folder as the current `PreProcess::Output` specs do.
- Unit specs for the new `documents` / `exists?` methods.
- Final flay sanity check with `code_quality_score_comparison` (the PR gate
  fails on total-score increase; the show view is deliberately not a copy of
  `extraction_jobs/show`).

## Approaches considered and rejected

- **Reuse `ExtractionJob` records for output** — create a real `ExtractionJob`
  during the run so the existing UI works untouched. Rejected: corrupts model
  semantics (not an extraction; `kind: full/sample` doesn't apply), and the
  existing UI would offer Delete/Cancel against data the harvest depends on.
- **Inline preview on the pipeline-job details page** — rejected: clunky
  pagination inside a report page, doesn't follow the "same pattern as
  navigating and viewing extracted data" the PO asked for.

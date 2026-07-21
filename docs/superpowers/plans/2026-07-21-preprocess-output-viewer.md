# Preprocess Output Viewer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Read-only UI to navigate and view the preprocessed output data a pre-processing block feeds forward into the harvest.

**Architecture:** A new `PreprocessOutputsController` (index/show) nested under a pipeline's harvest definitions. The read side lives on the existing `PreProcess::Output` PORO (`documents`, `exists?`), which pages the on-disk output through the existing `Extraction::Documents` machinery. Views are slim ERB modeled on the extraction-jobs index/show; entry point is a link on the preprocess block card.

**Tech Stack:** Rails 7.2, ERB + Bootstrap 5, Kaminari, RSpec + FactoryBot.

**Spec:** `docs/superpowers/specs/2026-07-21-preprocess-output-viewer-design.md`

## Global Constraints

- Work on branch `ba/preprocessing-pipeline` — the preprocess feature only exists here.
- View-only: routes are `only: %i[index show]`. No create/destroy/cancel anywhere.
- No new gems, no service objects, no new JS. Reuse existing helpers (`job_status_badge`), partials (`shared/pagination_above_table`, `shared/pagination_below_table`), and the `extraction-result-viewer` JS mount.
- Copy is inline in views (matches every existing view in this app — no i18n entries needed because there are no flash messages).
- Do NOT modify shared partials (`_definition_header`, `_definition_extraction_card`, `_definition_transformation_card`, `pipelines/_card`) — enrichment blocks must be untouched.
- Commit messages: conventional commits (`feat:`, `test:`), **no Co-Authored-By trailer**.
- Lint gates: `bundle exec rubocop`, `bundle exec erb_lint --lint-all` must pass. The CI code-quality gate fails if the flay/flog/reek total worsens — final task verifies.
- Test env has `show_exceptions = :none`, so scoping failures are asserted with `raise_error(ActiveRecord::RecordNotFound)`, not `have_http_status(:not_found)`.

---

### Task 1: Read side on `PreProcess::Output`

**Files:**
- Modify: `app/supplejack/pre_process/output.rb`
- Test: `spec/supplejack/pre_process/output_spec.rb`

**Interfaces:**
- Consumes: existing `PreProcess::Output#initialize(pipeline_job_id, position)`, `#write_page(page, records)`, `.folder(pipeline_job_id, position)`.
- Produces: `PreProcess::Output#documents` → `Extraction::Documents` (supports `[](page)`, `total_pages`); `PreProcess::Output#exists?` → Boolean. Task 2's controller calls both.

- [ ] **Step 1: Write the failing tests**

Append inside the existing `RSpec.describe PreProcess::Output do` block in `spec/supplejack/pre_process/output_spec.rb` (after the `#write_page` describe):

```ruby
  describe '#documents' do
    it 'returns pageable Extraction::Documents for the output folder' do
      output.write_page(1, [{ 'url' => '/a' }])

      documents = output.documents

      expect(documents).to be_a(Extraction::Documents)
      expect(documents.total_pages).to eq(1)
      expect(JSON.parse(documents[1].body)['records']).to eq([{ 'url' => '/a' }])
    end
  end

  describe '#exists?' do
    it 'is false when nothing has been written' do
      expect(output.exists?).to be false
    end

    it 'is true once a page has been written' do
      output.write_page(1, [{ 'url' => '/a' }])

      expect(output.exists?).to be true
    end
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/supplejack/pre_process/output_spec.rb`
Expected: 3 failures, each `NoMethodError: undefined method 'documents'` / `'exists?'`

- [ ] **Step 3: Write the implementation**

In `app/supplejack/pre_process/output.rb`, add above `private` (after `write_page`):

```ruby
    def documents
      Extraction::Documents.new(@folder)
    end

    def exists?
      Dir.glob("#{@folder}/**/*.json").any?
    end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/supplejack/pre_process/output_spec.rb`
Expected: all examples pass (existing 3 + new 3)

- [ ] **Step 5: Commit**

```bash
git add app/supplejack/pre_process/output.rb spec/supplejack/pre_process/output_spec.rb
git commit -m "feat: add read side to PreProcess::Output"
```

---

### Task 2: Routes, controller, views, breadcrumbs

**Files:**
- Modify: `config/routes.rb:80-105` (inside `resources :harvest_definitions`)
- Create: `app/controllers/preprocess_outputs_controller.rb`
- Create: `app/views/preprocess_outputs/index.html.erb`
- Create: `app/views/preprocess_outputs/show.html.erb`
- Modify: `config/breadcrumbs/pipelines.rb` (append)
- Test: `spec/requests/preprocess_outputs_spec.rb`

**Interfaces:**
- Consumes: `PreProcess::Output#documents` / `#exists?` from Task 1; existing helpers `job_status_badge(report, job)`, partials `shared/pagination_above_table` and `shared/pagination_below_table`.
- Produces: named routes `pipeline_harvest_definition_preprocess_outputs_path(pipeline, harvest_definition)` (index) and `pipeline_harvest_definition_preprocess_output_path(pipeline, harvest_definition, pipeline_job)` (show, `:id` = pipeline job id). Task 3's card link uses the index path.

- [ ] **Step 1: Write the failing request specs**

Create `spec/requests/preprocess_outputs_spec.rb`:

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PreprocessOutputs' do
  let(:user)     { create(:user) }
  let(:pipeline) { create(:pipeline) }
  let(:preprocess_definition) do
    create(:harvest_definition, kind: 'preprocess', position: 0, pipeline:)
  end
  let(:pipeline_job) { create(:pipeline_job, pipeline:) }
  let(:output)       { PreProcess::Output.new(pipeline_job.id, preprocess_definition.position) }

  before { sign_in user }

  after { FileUtils.rm_rf(PreProcess::Output.folder(pipeline_job.id, preprocess_definition.position)) }

  describe '#index' do
    it 'lists runs that have preprocessed data' do
      output.write_page(1, [{ 'title' => 'Record A' }])

      get pipeline_harvest_definition_preprocess_outputs_path(pipeline, preprocess_definition)

      expect(response).to be_successful
      expect(response.body).to include "Job ##{pipeline_job.id}"
    end

    it 'does not list runs without preprocessed data' do
      pipeline_job

      get pipeline_harvest_definition_preprocess_outputs_path(pipeline, preprocess_definition)

      expect(response).to be_successful
      expect(response.body).not_to include "Job ##{pipeline_job.id}"
      expect(response.body).to include 'This block has no pre-processed data yet'
    end
  end

  describe '#show' do
    it 'displays the preprocessed records for a page' do
      output.write_page(1, [{ 'title' => 'Record A' }])

      get pipeline_harvest_definition_preprocess_output_path(pipeline, preprocess_definition, pipeline_job)

      expect(response).to be_successful
      expect(response.body).to include 'Record A'
    end

    it 'displays a message when the run has no preprocessed data' do
      get pipeline_harvest_definition_preprocess_output_path(pipeline, preprocess_definition, pipeline_job)

      expect(response).to be_successful
      expect(response.body).to include 'This run has no pre-processed data'
    end

    it 'raises RecordNotFound for a pipeline job belonging to another pipeline' do
      other_job = create(:pipeline_job)

      expect do
        get pipeline_harvest_definition_preprocess_output_path(pipeline, preprocess_definition, other_job)
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
```

- [ ] **Step 2: Run specs to verify they fail**

Run: `bundle exec rspec spec/requests/preprocess_outputs_spec.rb`
Expected: FAIL with `NoMethodError: undefined method 'pipeline_harvest_definition_preprocess_outputs_path'` (route doesn't exist yet)

- [ ] **Step 3: Add the routes**

In `config/routes.rb`, inside `resources :harvest_definitions, only: %i[create update destroy] do` (line 80), add as the first nested line:

```ruby
      resources :preprocess_outputs, only: %i[index show]
```

- [ ] **Step 4: Add the controller**

Create `app/controllers/preprocess_outputs_controller.rb`:

```ruby
# frozen_string_literal: true

class PreprocessOutputsController < ApplicationController
  before_action :find_pipeline
  before_action :find_harvest_definition

  def index
    jobs_with_output = @pipeline.pipeline_jobs.order(created_at: :desc).select do |pipeline_job|
      preprocess_output(pipeline_job).exists?
    end

    @pipeline_jobs = Kaminari.paginate_array(jobs_with_output).page(params[:page])
  end

  def show
    @pipeline_job = @pipeline.pipeline_jobs.find(params[:id])
    @documents = preprocess_output(@pipeline_job).documents
    @document = @documents[params[:page]]
  end

  private

  def preprocess_output(pipeline_job)
    PreProcess::Output.new(pipeline_job.id, @harvest_definition.position)
  end

  def find_pipeline
    @pipeline = Pipeline.find(params[:pipeline_id])
  end

  def find_harvest_definition
    @harvest_definition = HarvestDefinition.find(params[:harvest_definition_id])
  end
end
```

- [ ] **Step 5: Add the breadcrumbs**

Append to `config/breadcrumbs/pipelines.rb`:

```ruby

crumb :preprocess_outputs do |pipeline, harvest_definition|
  link 'Pre-processed Data', pipeline_harvest_definition_preprocess_outputs_path(pipeline, harvest_definition)
  parent :pipeline, pipeline
end

crumb :preprocess_output do |pipeline, harvest_definition, pipeline_job|
  link pipeline_job.id
  parent :preprocess_outputs, pipeline, harvest_definition
end
```

- [ ] **Step 6: Add the index view**

Create `app/views/preprocess_outputs/index.html.erb` (card grid modeled on `app/views/jobs/_jobs.html.erb`; status badge shows the block's harvest report status when the run produced one, falling back to the run's own status — same rule as `job_status_badge` everywhere else):

```erb
<%= content_for(:title) { 'Pre-processed data' } %>
<% breadcrumb :preprocess_outputs, @pipeline, @harvest_definition %>

<%= content_for(:header) do %>
  <h1 class='my-4'><%= @harvest_definition.source_id %>: pre-processed data</h1>
<% end %>

<%- if @pipeline_jobs.any? %>
  <div class='row'>
    <%- @pipeline_jobs.each do |pipeline_job| %>
      <div class='col-3'>
        <%= link_to pipeline_harvest_definition_preprocess_output_path(
              @pipeline, @harvest_definition, pipeline_job
            ),
                    class: 'card card--clickable mb-3' do %>
          <div class='card-body'>
            <h5 class='card-title'>Job #<%= pipeline_job.id %></h5>
            <h6 class='card-subtitle'><%= pipeline_job.created_at.to_fs(:light) %></h6>

            <% report = pipeline_job.harvest_jobs
                                    .find_by(harvest_definition: @harvest_definition)&.harvest_report %>
            <%= job_status_badge(report, pipeline_job) %>
          </div>
        <% end %>
      </div>
    <%- end %>

    <%= render 'shared/pagination_below_table', items: @pipeline_jobs %>
  </div>
<% else %>
  <p>This block has no pre-processed data yet. Run the pipeline to generate some.</p>
<% end %>
```

- [ ] **Step 7: Add the show view**

Create `app/views/preprocess_outputs/show.html.erb` (slim version of `app/views/extraction_jobs/show.html.erb` — Result viewer only, no Request/Response tabs, no action buttons):

```erb
<%= content_for(:title) { 'Pre-processed data' } %>
<% breadcrumb :preprocess_output, @pipeline, @harvest_definition, @pipeline_job %>

<%= content_for(:header) do %>
  <h1>Pre-processed Data</h1>
  <p>
    <span class="me-1"><%= @harvest_definition.source_id %></span>|
    <span class="ms-1"><strong>Job #<%= @pipeline_job.id %>, <%= @pipeline_job.created_at.to_fs(:verbose) %></strong></span>
  </p>
<% end %>

<div class="my-4">
  <span class="me-1">Total Pages: <%= @documents.total_pages %></span>
  <%= render 'shared/pagination_above_table', items: @documents %>
</div>

<% if @documents.total_pages.zero? %>
  <p>This run has no pre-processed data.</p>
<% elsif @document.size_in_bytes > 10.megabytes %>
  <p>This page is too large to preview in the browser. It has still been pre-processed and will be harvested normally.</p>
<% else %>
  <div class="record-view record-view--extraction-result">
    <div
      id="extraction-result-viewer"
      data-results="<%= @document.body %>"
      data-format="JSON">
    </div>
  </div>
<% end %>
```

- [ ] **Step 8: Run specs to verify they pass**

Run: `bundle exec rspec spec/requests/preprocess_outputs_spec.rb`
Expected: 5 examples, 0 failures

- [ ] **Step 9: Commit**

```bash
git add config/routes.rb app/controllers/preprocess_outputs_controller.rb \
  app/views/preprocess_outputs config/breadcrumbs/pipelines.rb \
  spec/requests/preprocess_outputs_spec.rb
git commit -m "feat: add read-only viewer for preprocess output data"
```

---

### Task 3: Entry link on the preprocess block card

**Files:**
- Modify: `app/views/pipelines/_preprocess_definition.html.erb` (between the `definition_header` render and `<div class='row'>`)
- Test: `spec/requests/preprocess_outputs_spec.rb` (append)

**Interfaces:**
- Consumes: `pipeline_harvest_definition_preprocess_outputs_path` from Task 2.
- Produces: nothing downstream — final user-facing wiring.

- [ ] **Step 1: Write the failing test**

Append to the `RSpec.describe 'PreprocessOutputs'` block in `spec/requests/preprocess_outputs_spec.rb`:

```ruby
  describe 'navigation from the pipeline page' do
    it 'links the preprocess block to its pre-processed data' do
      preprocess_definition

      get pipeline_path(pipeline)

      expect(response.body).to include(
        pipeline_harvest_definition_preprocess_outputs_path(pipeline, preprocess_definition)
      )
    end
  end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/preprocess_outputs_spec.rb`
Expected: 1 failure — pipeline page body does not include the preprocess outputs path

- [ ] **Step 3: Add the link**

In `app/views/pipelines/_preprocess_definition.html.erb`, insert between the `definition_header` render (ends line 19) and `<div class='row'>` (line 21):

```erb
<%= link_to pipeline_harvest_definition_preprocess_outputs_path(@pipeline, preprocess_definition),
            class: 'btn btn-outline-primary mb-4' do %>
  <i class="bi bi-eye" aria-hidden="true"></i> View pre-processed data
<% end %>
```

(`btn-outline-primary` is already used in `app/views/automation_templates/_header.html.erb` — no new design-system values.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/requests/preprocess_outputs_spec.rb`
Expected: 6 examples, 0 failures

- [ ] **Step 5: Commit**

```bash
git add app/views/pipelines/_preprocess_definition.html.erb spec/requests/preprocess_outputs_spec.rb
git commit -m "feat: link preprocess block card to its pre-processed data"
```

---

### Task 4: Full verification and quality gates

**Files:** none created — verification only.

**Interfaces:**
- Consumes: everything from Tasks 1–3.
- Produces: green branch, ready for review.

- [ ] **Step 1: Run the neighbouring suites**

Run: `bundle exec rspec spec/supplejack/pre_process spec/requests/preprocess_outputs_spec.rb spec/requests/pipelines_spec.rb spec/requests/extraction_jobs_spec.rb`
Expected: 0 failures

- [ ] **Step 2: Ruby lint**

Run: `bundle exec rubocop app/controllers/preprocess_outputs_controller.rb app/supplejack/pre_process/output.rb`
Expected: no offenses

- [ ] **Step 3: ERB lint**

Run: `bundle exec erb_lint --lint-all`
Expected: no offenses (matches the CI `erblint` job)

- [ ] **Step 4: Code-quality (flay) gate check**

The PR's "Code quality" check fails if the weighted flay+flog+reek total increases vs `main`. Reproduce locally using the clone at `/Users/ben/Backpack/code/data-delivery/code_quality_score` (already set up for Ruby 3.4 — see `.claude/handovers/2026-07-21_1129-code-quality-flay-refactor.md` Key Context):

```bash
cd /Users/ben/Backpack/code/data-delivery/code_quality_score
git -C /Users/ben/Backpack/code/data-delivery/supplejack_harvester worktree add /tmp/sjh-main main
RBENV_VERSION=3.4.10 bundle exec exe/code_quality_score_comparison /tmp/sjh-main/ /Users/ben/Backpack/code/data-delivery/supplejack_harvester/
git -C /Users/ben/Backpack/code/data-delivery/supplejack_harvester worktree remove /tmp/sjh-main
```

Expected: output does NOT contain "got worse". If it does, the duplication is almost certainly between `preprocess_outputs/index.html.erb` and `jobs/_jobs.html.erb` or between the two show views — extract only the genuinely identical chunk into a shared partial (see the handover's "flay whack-a-mole" note: derive strings inside the partial, keep call-site locals to a minimum).

- [ ] **Step 5: Push**

```bash
git push origin ba/preprocessing-pipeline
```

Expected: CI green, including the "Code quality" check.

---

## Notes for the reviewer / PO

- Raw extracted data for a preprocess block was already viewable via the existing extraction-jobs routes; this plan adds the missing piece — the fed-forward output.
- Known gap (separate story): `extractions/<env>/preprocess/<pipeline_job_id>/` folders are never cleaned up when a pipeline job is destroyed.

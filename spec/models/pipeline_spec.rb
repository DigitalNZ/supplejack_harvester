# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pipeline do
  describe 'validations' do
    subject { build(:pipeline) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).case_insensitive.with_message('has already been taken') }
  end

  describe 'tags' do
    let(:pipeline) { create(:pipeline) }
    let(:production) { create(:tag, name: 'Production') }
    let(:audio) { create(:tag, name: 'Audio') }

    it 'has_many tags through pipeline_tags' do
      create(:pipeline_tag, pipeline:, tag: production)
      create(:pipeline_tag, pipeline:, tag: audio)

      expect(pipeline.tags).to contain_exactly(production, audio)
    end

    it 'destroys its pipeline_tags but not the tags' do
      create(:pipeline_tag, pipeline:, tag: production)

      expect { pipeline.destroy }.to change(PipelineTag, :count).by(-1)
      expect(production.reload).to be_persisted
    end

    describe '.tagged_with_all' do
      let!(:both) { create(:pipeline) }
      let!(:production_only) { create(:pipeline) }
      let!(:untagged) { create(:pipeline) }

      before do
        create(:pipeline_tag, pipeline: both, tag: production)
        create(:pipeline_tag, pipeline: both, tag: audio)
        create(:pipeline_tag, pipeline: production_only, tag: production)
      end

      it 'returns every pipeline when no slugs are given' do
        expect(described_class.tagged_with_all(nil)).to include both, production_only, untagged
        expect(described_class.tagged_with_all([])).to include both, production_only, untagged
        expect(described_class.tagged_with_all(['', nil])).to include both, production_only, untagged
      end

      it 'returns the pipelines carrying a single tag' do
        expect(described_class.tagged_with_all('production')).to contain_exactly(both, production_only)
      end

      it 'combines several tags with AND' do
        expect(described_class.tagged_with_all(%w[production audio])).to contain_exactly(both)
      end

      it 'is not confused by the same slug given twice' do
        expect(described_class.tagged_with_all(%w[production production])).to contain_exactly(both, production_only)
      end

      it 'returns nothing for a slug no tag uses' do
        expect(described_class.tagged_with_all('unknown')).to be_empty
      end

      it 'composes with ordering and pagination' do
        expect(described_class.tagged_with_all('production').order(:name).page(1)).to be_present
      end
    end
  end

  describe 'associations' do
    let(:pipeline) { create(:pipeline) }
    let!(:harvest_definition) { create(:harvest_definition, pipeline:) }
    let!(:enrichment_definition_one) { create(:harvest_definition, :enrichment, pipeline:) }
    let!(:enrichment_definition_two) { create(:harvest_definition, :enrichment, pipeline:) }

    it 'has_one harvest' do
      expect(pipeline.harvest).to eq harvest_definition
    end

    it 'has_many enrichments' do
      expect(pipeline.enrichments).to eq [enrichment_definition_one, enrichment_definition_two]
    end
    
    it 'has_many automation_step_templates' do
      expect(pipeline).to respond_to(:automation_step_templates)
    end
    
    it 'has_many automation_templates through automation_step_templates' do
      expect(pipeline).to respond_to(:automation_templates)
      
      other_pipeline = create(:pipeline)
      automation_template = create(:automation_template)
      other_template = create(:automation_template)
      
      create(:automation_step_template, pipeline: pipeline, automation_template: automation_template)
      create(:automation_step_template, pipeline: other_pipeline, automation_template: other_template)
      # Add pipeline to another template to test distinct
      create(:automation_step_template, pipeline: pipeline, automation_template: automation_template, position: 1)
      
      expect(pipeline.automation_templates).to include(automation_template)
      expect(pipeline.automation_templates).not_to include(other_template)
      # Even though pipeline is in automation_template twice, it should only be returned once
      expect(pipeline.automation_templates.count).to eq(1)
    end
  end

  describe '#ready_to_run?' do
    it 'returns false if there is no harvest' do
      pipeline = create(:pipeline)
      expect(pipeline.ready_to_run?).to be false
    end

    it 'returns false if the harvest has no extraction_definition' do
      pipeline = create(:pipeline)
      create(:harvest_definition, pipeline:, extraction_definition: nil)

      pipeline.reload

      expect(pipeline.ready_to_run?).to be false
    end

    it 'returns false if the harvest has no transformation_definition' do
      pipeline = create(:pipeline)
      create(:harvest_definition, pipeline:, transformation_definition: nil)

      pipeline.reload

      expect(pipeline.ready_to_run?).to be false
    end

    it 'returns false if the harvest transformation_definition has no fields' do
      pipeline = create(:pipeline)
      create(:harvest_definition, pipeline:)

      pipeline.reload

      expect(pipeline.harvest.transformation_definition.fields).to be_empty
      expect(pipeline.ready_to_run?).to be false
    end

    it 'returns true if the pipeline is ready to run' do
      pipeline = create(:pipeline)
      harvest_definition = create(:harvest_definition, pipeline:)
      create(:field, name: 'title', block: "JsonPath.new('title').on(record).first",
                     transformation_definition: harvest_definition.transformation_definition)

      expect(pipeline.ready_to_run?).to be(true)
    end
  end

  describe 'block ordering' do
    let(:pipeline) { create(:pipeline) }
    let!(:harvest)  { create(:harvest_definition, pipeline:, kind: :harvest,    position: 2) }
    let!(:pre_zero) { create(:harvest_definition, pipeline:, kind: :preprocess, position: 0) }
    let!(:pre_one)  { create(:harvest_definition, pipeline:, kind: :preprocess, position: 1) }

    it 'returns preprocess blocks in position order' do
      expect(pipeline.preprocesses.to_a).to eq([pre_zero, pre_one])
    end

    it 'returns the chain in position order' do
      expect(pipeline.ordered_blocks.to_a).to eq([pre_zero, pre_one, harvest])
    end

    it 'excludes enrichment definitions from the chain' do
      enrichment = create(:harvest_definition, pipeline:, kind: :enrichment, position: 0)

      expect(pipeline.ordered_blocks).not_to include(enrichment)
      expect(pipeline.ordered_blocks.to_a).to eq([pre_zero, pre_one, harvest])
    end
  end

  # The hand-repair AutomationWorker reaches for while it waits on a step
  # (AutomationWorker#schedule_job_check), and what the "anti stick" automation templates
  # were built around: a report left showing running with all of its workers accounted for.
  describe '#complete_finished_jobs!' do
    let(:destination) { create(:destination) }
    let(:pipeline)    { create(:pipeline) }
    let!(:block)      { create(:harvest_definition, pipeline:, kind: :harvest, position: 0) }
    let(:pipeline_job) do
      create(:pipeline_job, pipeline:, destination:, status: 'running', start_time: Time.zone.now,
                            harvest_definitions_to_run: [block.id.to_s])
    end
    let(:harvest_job) { create(:harvest_job, harvest_definition: block, pipeline_job:) }
    let!(:harvest_report) do
      create(:harvest_report, pipeline_job:, harvest_job:, kind: 'harvest',
                              extraction_status: 'completed', transformation_status: 'running',
                              load_status: 'running', delete_status: 'queued',
                              transformation_workers_queued: 1, transformation_workers_completed: 1,
                              load_workers_queued: 1, load_workers_completed: 1)
    end

    it 'completes a report whose workers have all finished' do
      pipeline.complete_finished_jobs!

      expect(harvest_report.reload.status).to eq 'completed'
    end

    # Repairing the report is only half of it: the run reads as running until something ends
    # it, which is the disagreement the anti stick templates were chasing.
    it 'ends the run the report belongs to' do
      pipeline.complete_finished_jobs!

      expect(pipeline_job.reload).to be_completed
    end

    it 'leaves a report whose workers are still outstanding alone' do
      harvest_report.update(transformation_workers_queued: 2)

      pipeline.complete_finished_jobs!

      expect(harvest_report.reload.transformation_status).to eq 'running'
    end

    # Why the anti stick templates could not rescue the harvests they were built for: this
    # only ever looks at reports showing running, so a run left running behind a report that
    # already reads completed is invisible to it. Those runs need the completion to have
    # worked in the first place (RunCompletion), or a backfill.
    # Why the anti stick templates could not rescue the harvests they were built for: this
    # only ever looks at reports showing running, so a run left running behind a report that
    # already reads completed is invisible to it. Those runs need the completion to have
    # worked in the first place (RunCompletion), or a backfill.
    context 'when the report already reads completed' do
      let!(:harvest_report) do
        create(:harvest_report, pipeline_job:, harvest_job:, kind: 'harvest',
                                extraction_status: 'completed', transformation_status: 'completed',
                                load_status: 'completed', delete_status: 'completed',
                                transformation_workers_queued: 1, transformation_workers_completed: 1,
                                load_workers_queued: 1, load_workers_completed: 1)
      end

      it 'cannot end the run it belongs to' do
        pipeline.complete_finished_jobs!

        expect(pipeline_job.reload).to be_running
      end
    end
  end
end

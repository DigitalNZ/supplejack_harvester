# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AutomationsHelper do
  describe '#step_status_class' do
    it 'returns the proper CSS class based on status' do
      expect(helper.step_status_class('completed')).to eq('completed')
      expect(helper.step_status_class('running')).to eq('running')
      expect(helper.step_status_class('errored')).to eq('errored')
      expect(helper.step_status_class('queued')).to eq('queued')
      expect(helper.step_status_class('not_started')).to eq('not-started')
      expect(helper.step_status_class('unknown')).to eq('not-started')
    end
  end
end 
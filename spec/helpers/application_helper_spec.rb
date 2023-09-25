# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationHelper do
  describe '#last_edited_by' do
    it 'returns nil if resource is nil' do
      expect(last_edited_by(nil)).to be_nil
    end

    it 'returns nil if last_edited_by is nil' do
      expect(last_edited_by(Pipeline.new)).to be_nil
    end

    it 'returns a formatted string if last_edited_by has a user' do
      user = create(:user)
      pipeline = Pipeline.new(last_edited_by: user)
      expect(last_edited_by(pipeline)).to eq "Last edited by #{user.username}"
    end
  end
end

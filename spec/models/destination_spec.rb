# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Destination do
  describe 'validations' do
    subject { build(:destination) }

    it { is_expected.to validate_presence_of(:name).with_message("can't be blank") }
    it { is_expected.to validate_presence_of(:url).with_message("can't be blank") }
    it { is_expected.to validate_presence_of(:api_key).with_message("can't be blank") }
    it { is_expected.to validate_uniqueness_of(:name).case_insensitive.with_message('has already been taken') }
  end
end

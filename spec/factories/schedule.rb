# frozen_string_literal: true

FactoryBot.define do
  factory :schedule do
    frequency { :daily }
    time      { '22:00' }
    harvest_definitions_to_run { [] }
  end
end

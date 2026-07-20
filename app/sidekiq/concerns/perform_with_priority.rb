# frozen_string_literal: true

module PerformWithPriority
  extend ActiveSupport::Concern

  class_methods do
    def perform_async_with_priority(priority, *)
      if priority.present?
        set(queue: priority).perform_async(*)
      else
        perform_async(*)
      end
    end

    def perform_in_with_priority(priority, interval, *)
      if priority.present?
        set(queue: priority).perform_in(interval, *)
      else
        perform_in(interval, *)
      end
    end
  end
end

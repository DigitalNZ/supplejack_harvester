
# frozen_string_literal: true

module PerformWithPriority
  extend ActiveSupport::Concern

  class_methods do
    def perform_async_with_priority(priority, *args)
      if priority.present?
        set(queue: priority).perform_async(*args)
      else
        perform_async(*args)
      end
    end
  
    def perform_in_with_priority(priority, interval, *args)
      if priority.present?
        set(queue: priority).perform_in(interval, *args)
      else
        perform_in(interval, *args)
      end
    end
  end
end
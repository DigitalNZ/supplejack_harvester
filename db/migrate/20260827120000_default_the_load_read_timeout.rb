# frozen_string_literal: true

# Every load names the wait it gives the destination, rather than a nil standing for whatever
# HTTP_READ_TIMEOUT happens to be. A minute is what nil already meant - Net::HTTP's own read
# timeout, which config/initializers/faraday.rb keeps - so the backfill changes no load's
# behaviour, only where the number is written down.
class DefaultTheLoadReadTimeout < ActiveRecord::Migration[8.0]
  def up
    change_column_null :load_definitions, :read_timeout, false, 60
    change_column_default :load_definitions, :read_timeout, 60
  end

  def down
    change_column_default :load_definitions, :read_timeout, nil
    change_column_null :load_definitions, :read_timeout, true
  end
end

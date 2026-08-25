# frozen_string_literal: true

# Builds a database from db/migrate alone and returns the db/schema.rb it dumps to,
# for a caller to compare against the committed one.
#
# The two drift with nothing noticing. db:migrate loads db/schema.rb outright when
# the database is empty rather than running the migrations, and the test database is
# loaded from the file as well, so nothing in a normal day re-derives the file from
# db/migrate. A schema.rb that has stopped describing what the migrations produce
# then survives every local run, and it is production that reads as the odd one out.
#
# The build happens in a throwaway database named after the current one and dropped
# again afterwards, so the development and test databases are left alone.
class SchemaVerification
  SCRATCH_SUFFIX = '_schema_verification'

  def initialize
    @source = ActiveRecord::Base.connection_db_config
  end

  def scratch_database = "#{source.database}#{SCRATCH_SUFFIX}"

  # The db/schema.rb that db/migrate produces, dumped from a database migrated from
  # nothing.
  def dump_from_migrations
    migrate_scratch_database
    dump
  ensure
    release_scratch_database
  end

  private

  attr_reader :source

  def scratch
    @scratch ||= source.configuration_hash.merge(database: scratch_database)
  end

  # The migrations are given ActiveRecord::Base's own connection, so that the ones
  # reaching for a model write to the throwaway database rather than to this one.
  def migrate_scratch_database
    recreate_scratch_database
    ActiveRecord::Base.establish_connection(scratch)
    ActiveRecord::Base.connection_pool.migration_context.migrate
  end

  def recreate_scratch_database
    drop_scratch_database
    ActiveRecord::Tasks::DatabaseTasks.create(scratch)
  end

  def release_scratch_database
    ActiveRecord::Base.establish_connection(source.configuration_hash)
    drop_scratch_database
  end

  # A database left behind by an interrupted run has to go before the migrations run
  # against it, so this is expected to find nothing to drop most of the time. Rails
  # announces that on stderr, which reads as a failure in a build log, so it is
  # swallowed here. A drop that fails for any other reason still raises.
  def drop_scratch_database
    announcements = $stderr
    $stderr = StringIO.new
    ActiveRecord::Tasks::DatabaseTasks.drop(scratch)
  ensure
    $stderr = announcements
  end

  def dump
    io = StringIO.new
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection_pool, io)
    io.string
  end
end

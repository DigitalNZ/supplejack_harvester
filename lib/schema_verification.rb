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

  delegate :database, to: :scratch, prefix: :scratch

  def initialize(verbose: false)
    @verbose = verbose
    @source = ActiveRecord::Base.connection_db_config
  end

  # The db/schema.rb that db/migrate produces, dumped from a database migrated from
  # nothing.
  def dump_from_migrations
    recreate_scratch_database
    ActiveRecord::Base.establish_connection(scratch.configuration_hash)
    migrate
    dump
  ensure
    ActiveRecord::Base.establish_connection(source.configuration_hash)
    drop_scratch_database
  end

  private

  attr_reader :source, :verbose

  def scratch
    @scratch ||= ActiveRecord::DatabaseConfigurations::HashConfig.new(
      source.env_name,
      source.name,
      source.configuration_hash.merge(database: "#{source.database}#{SCRATCH_SUFFIX}")
    )
  end

  def recreate_scratch_database
    drop_scratch_database
    ActiveRecord::Tasks::DatabaseTasks.create(scratch)
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

  def migrate
    was_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = verbose
    ActiveRecord::Base.connection_pool.migration_context.migrate
  ensure
    ActiveRecord::Migration.verbose = was_verbose
  end

  def dump
    io = StringIO.new
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection_pool, io)
    io.string
  end
end

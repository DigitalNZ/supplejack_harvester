# frozen_string_literal: true

# ------------------------------------------------------------
# Fails if db/schema.rb no longer describes what db/migrate produces, so that a
# schema.rb which has stopped matching the migrations fails a build here rather
# than turning into a migration failure later.
#
#   bundle exec rake schema_verification:verify
#   bundle exec rake schema_verification:verify VERBOSE=true
#
# Env:
#   VERBOSE  false  announce each migration as it runs
#
# The migrations are run in a throwaway database, so nothing local is touched. See
# lib/schema_verification.rb for how the two come to drift in the first place.
# ------------------------------------------------------------
namespace :schema_verification do
  desc 'Fail if db/schema.rb no longer describes what db/migrate produces.'
  task verify: :environment do
    verification = SchemaVerification.new(verbose: ENV['VERBOSE'] == 'true')
    committed = Rails.root.join('db/schema.rb')

    puts "Migrating #{verification.scratch_database} from nothing."
    from_migrations = verification.dump_from_migrations

    if from_migrations == committed.read
      puts 'db/schema.rb describes what the migrations produce.'
      next
    end

    generated = Rails.root.join('tmp/schema_from_migrations.rb')
    generated.write(from_migrations)
    puts 'db/schema.rb does not describe what the migrations produce:'
    system('diff', '--unified', committed.to_s, generated.to_s)
    abort 'Regenerate db/schema.rb from a database migrated from nothing, not from ' \
          'a development database, and commit the result.'
  end
end

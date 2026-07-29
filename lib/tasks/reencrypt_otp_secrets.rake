# frozen_string_literal: true

# Re-encrypts User#otp_secret so it uses the current (SHA-256) Active Record
# Encryption key derivation instead of the legacy SHA-1 derivation used before
# this app moved to `config.load_defaults 8.0`.
#
# Background: `otp_secret` (declared via devise-two-factor's `encrypts :otp_secret`)
# is a non-deterministic encrypted attribute. Records written under Rails <= 7.0
# defaults had their key derived with SHA-1; Rails 7.1+ uses SHA-256. We keep old
# data readable via
#   config.active_record.encryption.support_sha1_for_non_deterministic_encryption = true
# in config/application.rb. This task rewrites every otp_secret with the SHA-256
# key so that flag can eventually be removed.
#
# How it works: reading `otp_secret` decrypts it (falling back to the SHA-1 key
# when needed); forcing the attribute dirty and saving re-encrypts the plaintext
# with the primary SHA-256 scheme and a fresh IV. Plaintext is never changed, so
# users' 2FA keeps working throughout.
#
# Usage:
#   bin/rails otp:reencrypt_secrets            # apply
#   DRY_RUN=1 bin/rails otp:reencrypt_secrets  # report only, no writes
#
# Idempotent: safe to run repeatedly. Run it on every environment (UAT, prod)
# while the SHA-1 fallback is still enabled, then drop the flag.

# rubocop:disable Metrics/BlockLength
namespace :otp do
  desc 'Re-encrypt User#otp_secret with the current SHA-256 encryption key'
  task reencrypt_secrets: :environment do
    dry_run = otp_env_truthy?(ENV.fetch('DRY_RUN', nil))

    scope = User.where.not(otp_secret: nil)
    total = scope.count

    puts "Re-encrypting otp_secret for #{total} user(s)#{' (DRY RUN — no writes)' if dry_run}…"

    processed = 0
    reencrypted = 0
    skipped = 0
    failures = []

    scope.find_each(batch_size: 200) do |user|
      processed += 1

      # Skip rows whose stored ciphertext is blank (nothing to re-encrypt).
      if user.read_attribute_before_type_cast(:otp_secret).blank?
        skipped += 1
        next
      end

      begin
        # Force decryption so a genuinely undecryptable record fails loudly here
        # rather than silently writing garbage.
        user.otp_secret

        if dry_run
          reencrypted += 1
          next
        end

        user.otp_secret_will_change!
        user.save!(validate: false)
        reencrypted += 1
      rescue StandardError => e
        failures << { id: user.id, email: user.email, error: "#{e.class}: #{e.message}" }
      end
    end

    puts
    puts '─' * 60
    puts "Processed:    #{processed}"
    puts "Re-encrypted: #{reencrypted}#{' (would have)' if dry_run}"
    puts "Skipped:      #{skipped} (blank ciphertext)"
    puts "Failed:       #{failures.size}"

    unless failures.empty?
      puts
      puts 'Failures (left untouched — investigate before removing the SHA-1 fallback):'
      failures.each { |f| puts "  - user ##{f[:id]} <#{f[:email]}>: #{f[:error]}" }
    end

    puts '─' * 60
    puts dry_run ? 'Dry run complete. Re-run without DRY_RUN to apply.' : 'Done.'
  end
end
# rubocop:enable Metrics/BlockLength

def otp_env_truthy?(value)
  %w[1 true TRUE yes YES on ON].include?(value.to_s.strip)
end

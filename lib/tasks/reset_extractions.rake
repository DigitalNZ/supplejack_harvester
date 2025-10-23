# frozen_string_literal: true

require 'fileutils'
require 'aws-sdk-s3'
require 'active_support/number_helper'

# ------------------------------------------------------------
# All logic in one place (RuboCop-friendly, SRP per class)
# ------------------------------------------------------------
module Extractions
  # Centralized configuration. All env lookups live here.
  class Config
    DEFAULTS = {
      'BACKUP_ENV' => 'production',
      'BACKUP_BUCKET' => 's3-backup',
      'BACKUP_ROOT_PREFIX' => 'my_backup',
      'BACKUP_REGION' => 'us-east-1',
      'VOLUME_NAME' => 'my-volume',
      'SIZE_CONCURRENCY' => '8',
      'DOWNLOAD_CONCURRENCY' => '16',
      'MULTIPART_DOWNLOAD' => 'true',
      'LOCAL_EXTRACTIONS_DIR' => 'extractions/development'
    }.freeze

    attr_reader :backup_env, :bucket, :root_prefix, :region, :volume_name,
                :size_concurrency, :download_concurrency, :multipart_download,
                :local_extractions_dir

    def initialize(env = ENV)
      @backup_env            = fetch(env, 'BACKUP_ENV')
      @bucket                = fetch(env, 'BACKUP_BUCKET')
      @root_prefix           = fetch(env, 'BACKUP_ROOT_PREFIX')
      @region                = fetch(env, 'BACKUP_REGION')
      @volume_name           = fetch(env, 'VOLUME_NAME')
      @size_concurrency      = integer(fetch(env, 'SIZE_CONCURRENCY'), 1)
      @download_concurrency  = integer(fetch(env, 'DOWNLOAD_CONCURRENCY'), 1)
      @multipart_download    = truthy?(fetch(env, 'MULTIPART_DOWNLOAD'))
      @local_extractions_dir = fetch(env, 'LOCAL_EXTRACTIONS_DIR')
    end

    private

    def fetch(env, key) = env.fetch(key, DEFAULTS.fetch(key))

    def integer(value, min) = [value.to_i, min].max

    def truthy?(value) = %w[1 true TRUE yes YES on ON].include?(value)
  end

  # Minimal TTY-less progress bar.
  class ProgressBar
    BAR_WIDTH = 40

    def initialize(total_bytes:, total_items:)
      @total_bytes = total_bytes
      @total_items = total_items
      @done_bytes  = 0
      @done_items  = 0
      @mutex       = Mutex.new
      $stdout.sync = true
    end

    def tick(bytes:, items: 0)
      @mutex.synchronize do
        @done_bytes += bytes
        @done_items += items
        render
      end
    end

    def finish
      @mutex.synchronize { render(final: true) }
      puts
    end

    private

    def render(final: false)
      ratio = @total_bytes.zero? ? 1.0 : (@done_bytes.to_f / @total_bytes)
      ratio = ratio.clamp(0.0, 1.0)
      filled = (ratio * BAR_WIDTH).round
      bar = "[#{'#' * filled}#{'-' * (BAR_WIDTH - filled)}]"
      pct = (ratio * 100).round
      print "\r#{bar} #{pct}%  #{human(@done_bytes)}/#{human(@total_bytes)}  (#{@done_items}/#{@total_items} files)"
      puts if final
    end

    def human(bytes) = ActiveSupport::NumberHelper.number_to_human_size(bytes)
  end

  # Finds newest backup prefix containing pvc_pv_mapping.txt and extracts PVC name.
  class BackupLocator
    def initialize(config, s3_client: Aws::S3::Client.new(region: config.region))
      @config = config
      @s3     = s3_client
    end

    # @return [Array(String,String)] [backup_prefix, pvc_name]
    def latest_backup_with_pvc
      prefixes = list_backup_prefixes_sorted
      raise "No backups found under #{@config.root_prefix} in #{@config.bucket}" if prefixes.empty?

      prefixes.reverse_each do |prefix|
        pvc = extract_pvc_name(prefix, @config.volume_name)
        return [prefix, pvc] if pvc
      end

      raise 'Could not find pvc_pv_mapping.txt with the expected volume mapping.'
    end

    private

    def list_backup_prefixes_sorted
      prefixes = []
      paginate_prefixes { |batch| prefixes.concat(batch) }
      prefixes.sort
    end

    def paginate_prefixes
      token = nil
      loop do
        resp = @s3.list_objects_v2(
          bucket: @config.bucket,
          prefix: @config.root_prefix,
          delimiter: '/',
          continuation_token: token
        )
        yield resp.common_prefixes.map(&:prefix)
        break unless resp.is_truncated

        token = resp.next_continuation_token
      end
    end

    def extract_pvc_name(backup_prefix, volume_name)
      key = "#{backup_prefix}pvc_pv_mapping.txt"
      body = @s3.get_object(bucket: @config.bucket, key: key).body.read
      line = body.each_line.find { |l| l.start_with?(volume_name) }
      line&.split&.at(1)
    rescue Aws::S3::Errors::NoSuchKey
      nil
    end
  end

  # Estimates total bytes under each prefix (parallel).
  class SizeEstimator
    Result = Struct.new(:folder, :prefix, :bytes, :display_index, keyword_init: true)

    def initialize(config)
      @config = config
    end

    # @param prefixes [Array<Hash>] items with :folder, :prefix
    # @return [Array<Result>]
    def estimate(prefixes)
      results = parallel_map(prefixes) { |item, s3| Result.new(**item, bytes: s3_prefix_size(s3, item[:prefix])) }
      results.sort_by!(&:bytes)
      results
    end

    private

    def parallel_map(items)
      queue = Queue.new
      items.each { |i| queue << i }
      results       = []
      results_mutex = Mutex.new
      completed     = 0
      total         = items.size

      puts "Estimating sizes for #{total} folder(s)…"
      print_bar(total, total) if total.zero?

      threads = Array.new(@config.size_concurrency) do
        Thread.new do
          s3 = Aws::S3::Client.new(region: @config.region)
          loop do
            item = begin
              queue.pop(true)
            rescue StandardError
              nil
            end
            break unless item

            value = yield(item, s3)
            results_mutex.synchronize { results << value }

            completed += 1
            print_bar(completed, total)
          end
        end
      end

      threads.each(&:join)
      puts
      results
    end

    def s3_prefix_size(s3_client, prefix)
      total = 0
      token = nil
      loop do
        resp = s3_client.list_objects_v2(bucket: @config.bucket, prefix: prefix, continuation_token: token)
        resp.contents.each { |o| total += o.size }
        break unless resp.is_truncated

        token = resp.next_continuation_token
      end
      total
    end

    def print_bar(done, total)
      width  = 32
      ratio  = total.zero? ? 1.0 : (done.to_f / total)
      filled = (ratio * width).round
      bar    = "[#{'#' * filled}#{'-' * (width - filled)}]"
      pct    = (ratio * 100).round
      print "\r#{bar} #{done}/#{total} (#{pct}%)"
    end
  end

  # Downloads all objects under a given prefix into a local directory (parallel).
  class Downloader
    def initialize(config)
      @config = config
    end

    # Download a single S3 prefix to dest_dir with a bytes progress bar.
    def download_prefix(prefix:, dest_dir:)
      objects     = list_objects(prefix)
      filtered    = objects.reject { |o| o.key == prefix }
      total_bytes = filtered.sum(&:size)
      bar         = ProgressBar.new(total_bytes: total_bytes, total_items: filtered.size)

      queue = Queue.new
      filtered.each { |o| queue << o }

      threads = build_workers(queue, prefix, dest_dir, bar)
      threads.each(&:join)

      bar.finish
      puts "  #{filtered.size} file(s) downloaded."
    end

    private

    def list_objects(prefix)
      s3_client = Aws::S3::Client.new(region: @config.region)
      objs = []
      token = nil
      loop do
        resp = s3_client.list_objects_v2(bucket: @config.bucket, prefix: prefix, continuation_token: token)
        objs.concat(resp.contents)
        break unless resp.is_truncated

        token = resp.next_continuation_token
      end
      objs
    end

    def build_workers(queue, prefix, dest_dir, bar)
      Array.new(@config.download_concurrency) do
        Thread.new do
          client   = Aws::S3::Client.new(region: @config.region)
          resource = Aws::S3::Resource.new(client: client)
          bucket   = resource.bucket(@config.bucket)

          loop do
            obj = begin
              queue.pop(true)
            rescue StandardError
              nil
            end
            break unless obj

            process_object(bucket, obj, prefix, dest_dir, bar)
          end
        end
      end
    end

    def process_object(bucket, obj, prefix, dest_dir, bar)
      rel = obj.key.delete_prefix(prefix)
      return if rel.empty?

      local_path = File.join(dest_dir, rel)
      FileUtils.mkdir_p(File.dirname(local_path))

      bytes_written = transfer_object(bucket, obj, local_path)
      bar.tick(bytes: bytes_written, items: 1)
    end

    # Use multipart for large files; otherwise single GET.
    def transfer_object(bucket, obj, local_path)
      if multipart?(obj.size)
        bucket.object(obj.key)
              .download_file(local_path, thread_count: 4, part_size: 8 * 1024 * 1024)
        obj.size.to_i
      else
        bucket.client.get_object(bucket: bucket.name, key: obj.key, response_target: local_path)
        File.size(local_path)
      end
    rescue StandardError => e
      warn "  ! Failed #{obj.key}: #{e.class} #{e.message}"
      0
    end

    def multipart?(size_bytes)
      @config.multipart_download && size_bytes.to_i >= (8 * 1024 * 1024)
    end
  end

  # Parses user selections like "1,3-5,12"
  class Selector
    class << self
      def parse(input, max:)
        return (1..max).to_a if input.strip.casecmp('all').zero?

        tokens = input.split(',').map!(&:strip)
        expand_tokens(tokens, max).uniq.sort
      end

      private

      def expand_tokens(tokens, max)
        tokens.flat_map { |t| expand_token(t, max) }
      end

      def expand_token(token, max)
        case token
        when /\A\d+\z/
          num = token.to_i
          num.between?(1, max) ? [num] : []
        when /\A(\d+)\s*-\s*(\d+)\z/
          a = Regexp.last_match(1).to_i
          b = Regexp.last_match(2).to_i
          range = a <= b ? (a..b) : (b..a)
          range.select { |n| n.between?(1, max) }
        else
          []
        end
      end
    end
  end
end

# ------------------------------------------------------------
# Rake task
# ------------------------------------------------------------
# rubocop:disable Metrics/BlockLength
namespace :reset_extractions do
  desc 'List S3 extraction folders with sizes (parallel), select subset, and download to local.'
  task execute: :environment do
    config = Extractions::Config.new

    # 1) Which extraction folders do we care about (from DB)?
    extraction_folders = ExtractionJob
                         .where(
                           id: TransformationDefinition.where.not(extraction_job_id: nil)
                                                       .select(:extraction_job_id)
                                                       .distinct
                         )
                         .select(:id, :created_at)
                         .map { |ej| ej.extraction_folder.split('/').last }
                         .uniq
    raise 'No extraction folders resolved from DB.' if extraction_folders.empty?

    # 2) Find newest backup + PVC
    locator = Extractions::BackupLocator.new(config)
    backup_prefix, pvc_name = locator.latest_backup_with_pvc

    base_prefix = "#{backup_prefix}#{pvc_name}/#{config.backup_env}/" # e.g. .../production/

    # 3) Estimate sizes in parallel (sorted asc)
    estimator = Extractions::SizeEstimator.new(config)
    rows = estimator.estimate(extraction_folders.map { |f| { folder: f, prefix: "#{base_prefix}#{f}/" } })

    cumulative = 0
    rows.each_with_index do |row, idx|
      cumulative += row.bytes
      puts format(
        '%<idx>3d. %<size>12s  cum: %<cum>12s  s3://%<bucket>s/%<prefix>s',
        idx: idx + 1,
        size: human(row.bytes),
        cum: human(cumulative),
        bucket: config.bucket,
        prefix: row.prefix
      )
      row[:display_index] = idx + 1
    end
    puts
    puts "TOTAL (all): #{human(cumulative)} (#{cumulative} bytes)"
    puts

    # 4) Selection
    puts <<~HELP
      Select folders to download:
        - Use numbers, commas, and ranges, e.g. 1,3-5,12
        - Or type 'all' to download all
        - Press Enter to cancel
    HELP
    print 'Your selection: '
    selection = $stdin.gets.to_s.strip
    if selection.empty?
      puts 'No selection. Exiting.'
      next
    end

    idxs = Extractions::Selector.parse(selection, max: rows.size)
    if idxs.empty?
      puts 'No valid indices. Exiting.'
      next
    end

    chosen = rows.select { |r| idxs.include?(r[:display_index]) }
    chosen_bytes = chosen.sum(&:bytes)
    puts
    puts "Selected #{chosen.size} folder(s), total #{human(chosen_bytes)}"
    chosen.each do |row|
      puts format(
        '  - %<size>12s  s3://%<bucket>s/%<prefix>s',
        size: human(row.bytes),
        bucket: config.bucket,
        prefix: row.prefix
      )
    end
    puts

    # 5) Download chosen prefixes (parallel per prefix)
    dest_root = config.local_extractions_dir
    FileUtils.mkdir_p(dest_root)
    downloader = Extractions::Downloader.new(config)

    puts "Downloading to: #{File.expand_path(dest_root)} " \
         "(#{config.download_concurrency} threads, multipart: #{config.multipart_download})"

    chosen.each do |row|
      dest_folder = File.join(dest_root, row.folder)
      FileUtils.mkdir_p(dest_folder)
      puts "\n→ #{row.folder}  (#{human(row.bytes)})"
      downloader.download_prefix(prefix: row.prefix, dest_dir: dest_folder)
    end

    puts "\nDone."
  end
  # rubocop:enable Metrics/BlockLength
end
def human(bytes)
  ActiveSupport::NumberHelper.number_to_human_size(bytes)
end

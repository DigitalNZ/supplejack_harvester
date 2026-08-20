# frozen_string_literal: true

require 'English'
require 'fileutils'
require 'open3'
require 'shellwords'
require 'tempfile'
require 'active_support/number_helper'

# ------------------------------------------------------------
# Pulls extraction folders off the production EFS volume, which is mounted into
# the harvester pods, by streaming a tar over `kubectl exec`.
#
# The harvester image ships BusyBox, so anything run inside the pod has to stay
# POSIX (no `find -printf`, no bashisms). Only the local half of the pipe is GNU.
# ------------------------------------------------------------
module Extractions
  def self.human(bytes) = ActiveSupport::NumberHelper.number_to_human_size(bytes)

  # An empty directory is treated as absent: it is what a failed run leaves behind.
  def self.downloaded?(dest_root, folder)
    path = File.join(dest_root, folder)
    Dir.exist?(path) && Dir.children(path).any?
  end

  # Centralized configuration. All env lookups live here.
  class Config
    DEFAULTS = {
      'KUBECTL' => 'kubectl',
      'NAMESPACE' => 'production',
      'POD' => '',
      'POD_PATTERN' => '\Aharvester-(?!sidekiq|redis)',
      'REMOTE_EXTRACTIONS_DIR' => '/app/extractions/production',
      'LOCAL_EXTRACTIONS_DIR' => 'extractions/development',
      'SELECTION' => '',
      'FORCE' => 'false'
    }.freeze

    attr_reader :kubectl, :namespace, :pod, :pod_pattern, :remote_dir, :local_dir, :selection

    # Re-download folders that are already present locally.
    def force? = @force

    def initialize(env = ENV)
      @kubectl     = fetch(env, 'KUBECTL')
      @namespace   = fetch(env, 'NAMESPACE')
      @pod         = fetch(env, 'POD')
      @pod_pattern = fetch(env, 'POD_PATTERN')
      @remote_dir  = fetch(env, 'REMOTE_EXTRACTIONS_DIR')
      @local_dir   = fetch(env, 'LOCAL_EXTRACTIONS_DIR')
      @selection   = fetch(env, 'SELECTION')
      @force       = truthy?(fetch(env, 'FORCE'))
    end

    private

    def fetch(env, key) = env.fetch(key, DEFAULTS.fetch(key))

    def truthy?(value) = %w[1 true TRUE yes YES on ON].include?(value)
  end

  # Thin wrapper over the kubectl binary.
  class Kubectl
    Error = Class.new(StandardError)

    def initialize(config)
      @config = config
    end

    # @return [String] stdout of the command
    def capture(*args)
      out, err, status = Open3.capture3(@config.kubectl, *args)
      raise Error, "kubectl #{args.first} failed: #{err.strip}" unless status.success?

      out
    end

    # Runs a shell snippet inside the pod and returns its stdout.
    def exec_script(pod, script)
      capture('exec', '-n', @config.namespace, pod, '--', 'sh', '-c', script)
    end

    # The `kubectl exec` half of a tar pipeline, ready to be embedded in a shell command.
    def exec_command(pod, *remote_argv)
      Shellwords.join([@config.kubectl, 'exec', '-n', @config.namespace, pod, '--', *remote_argv])
    end
  end

  # Picks a running harvester pod to read the volume from.
  class PodLocator
    def initialize(config, kubectl)
      @config  = config
      @kubectl = kubectl
    end

    # @return [String] pod name
    def call
      return verify(@config.pod) unless @config.pod.empty?

      pattern = Regexp.new(@config.pod_pattern)
      pod     = running_pods.find { |name| name.match?(pattern) }
      raise "No running pod in #{@config.namespace} matching #{@config.pod_pattern}" unless pod

      pod
    end

    private

    def running_pods
      @kubectl.capture(
        'get', 'pods', '-n', @config.namespace,
        '--field-selector=status.phase=Running',
        '-o', 'custom-columns=:metadata.name', '--no-headers'
      ).split
    end

    def verify(pod)
      return pod if running_pods.include?(pod)

      raise "Pod #{pod} is not running in #{@config.namespace}"
    end
  end

  # Asks the pod for the size and file count of each candidate folder, in one round trip.
  class FolderInspector
    Row = Struct.new(:folder, :bytes, :files, :present, :display_index, keyword_init: true)

    def initialize(config, kubectl, pod)
      @config  = config
      @kubectl = kubectl
      @pod     = pod
    end

    # @param folders [Array<String>]
    # @return [Array<Row>] sorted by size ascending
    def inspect_all(folders)
      puts "Measuring #{folders.size} folder(s) on #{@config.namespace}/#{@pod}…"
      parse(@kubectl.exec_script(@pod, script(folders))).sort_by(&:bytes)
    end

    private

    # `du` counts directory blocks, so sizes run slightly high on deeply nested
    # folders. That is fine: they only exist to help you choose what to pull.
    def script(folders)
      <<~SH
        cd #{Shellwords.escape(@config.remote_dir)} || exit 1
        for f in #{folders.map { |f| Shellwords.escape(f) }.join(' ')}; do
          if [ -d "$f" ]; then
            b=$(du -sb "$f" 2>/dev/null | cut -f1)
            [ -z "$b" ] && b=$(( $(du -sk "$f" | cut -f1) * 1024 ))
            n=$(find "$f" -type f | wc -l | tr -d ' ')
            printf '%s|%s|%s\\n' "$f" "$b" "$n"
          else
            printf '%s|-|-\\n' "$f"
          fi
        done
      SH
    end

    def parse(output)
      output.each_line.filter_map do |line|
        folder, bytes, files = line.strip.split('|')
        next if folder.to_s.empty?

        present = bytes != '-'
        Row.new(folder: folder, bytes: present ? bytes.to_i : 0,
                files: present ? files.to_i : 0, present: present)
      end
    end
  end

  # Minimal TTY-less progress bar, ticked once per extracted file.
  class ProgressBar
    BAR_WIDTH = 40

    def initialize(total_items:, total_bytes:)
      @total_items = total_items
      @total_bytes = total_bytes
      @done_items  = 0
      $stdout.sync = true
    end

    def tick(items: 1)
      @done_items += items
      render
    end

    def finish
      render
      puts
    end

    private

    def render
      ratio  = @total_items.zero? ? 1.0 : (@done_items.to_f / @total_items).clamp(0.0, 1.0)
      filled = (ratio * BAR_WIDTH).round
      bar    = "[#{'#' * filled}#{'-' * (BAR_WIDTH - filled)}]"
      print "\r  #{bar} #{(ratio * 100).round}%  #{@done_items}/#{@total_items} files  " \
            "(#{Extractions.human(@total_bytes)})"
    end
  end

  # Streams one folder out of the pod as a tar and unpacks it locally.
  class Downloader
    def initialize(config, kubectl, pod)
      @config  = config
      @kubectl = kubectl
      @pod     = pod
    end

    def download(row, dest_root)
      # tar merges into an existing tree, leaving files that production no longer
      # has. Clearing first makes every download an exact copy of the volume.
      FileUtils.rm_rf(File.join(dest_root, row.folder))
      FileUtils.mkdir_p(dest_root)
      bar = ProgressBar.new(total_items: row.files, total_bytes: row.bytes)

      Tempfile.create('kubectl-stderr') do |errfile|
        run_pipeline(row, dest_root, errfile, bar)
        bar.finish
        next if $CHILD_STATUS.success?

        raise Kubectl::Error, "Download of #{row.folder} failed: #{File.read(errfile.path).strip}"
      end
    end

    private

    def run_pipeline(row, dest_root, errfile, bar)
      IO.popen(['bash', '-c', pipeline(row.folder, dest_root, errfile.path)], 'r') do |io|
        io.each_line { |line| count(line, row.folder, bar) }
      end
    end

    # `tar xzv` names every entry it writes, which is what drives the progress bar.
    # kubectl's own stderr goes to a file: merging it into the pipe would corrupt the tar.
    def pipeline(folder, dest_root, errpath)
      remote = @kubectl.exec_command(@pod, 'tar', 'czf', '-', '-C', @config.remote_dir, folder)
      local  = Shellwords.join(['tar', 'xzvf', '-', '-C', dest_root])
      "set -o pipefail; #{remote} 2>#{Shellwords.escape(errpath)} | #{local} 2>&1"
    end

    # tar lists directories too; only files are counted so the bar matches `find -type f`.
    def count(line, folder, bar)
      entry = line.chomp
      unless entry.start_with?(folder)
        warn "\n  ! #{entry}" unless entry.strip.empty?
        return
      end

      bar.tick unless entry.end_with?('/')
    end
  end

  # Parses user selections like "1,3-5,12"
  class Selector
    class << self
      def parse(input, max:)
        return (1..max).to_a if input.strip.casecmp('all').zero?

        expand_tokens(input.split(',').map!(&:strip), max).uniq.sort
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
          (a <= b ? (a..b) : (b..a)).select { |n| n.between?(1, max) }
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
  desc 'List extraction folders on the production volume, select a subset, and download them locally.'
  task execute: :environment do
    config  = Extractions::Config.new
    kubectl = Extractions::Kubectl.new(config)

    # 1) Which extraction folders do we care about (from DB)?
    extraction_folders = ExtractionJob
                         .where(
                           id: TransformationDefinition.where.not(extraction_job_id: nil)
                                                       .select(:extraction_job_id)
                                                       .distinct
                         )
                         .select(:id, :created_at)
                         .map { |ej| File.basename(ej.extraction_folder) }
                         .uniq
    raise 'No extraction folders resolved from DB.' if extraction_folders.empty?

    # 2) Find a pod with the volume mounted
    pod = Extractions::PodLocator.new(config, kubectl).call
    puts "Reading #{config.namespace}/#{pod}:#{config.remote_dir}"
    puts

    # 3) Measure them (one exec, sorted asc)
    all_rows = Extractions::FolderInspector.new(config, kubectl, pod).inspect_all(extraction_folders)
    rows, missing = all_rows.partition(&:present)

    if missing.any?
      puts "#{missing.size} folder(s) referenced by the DB no longer exist on the volume:"
      missing.first(10).each { |row| puts "  - #{row.folder}" }
      puts "  … and #{missing.size - 10} more" if missing.size > 10
      puts
    end

    if rows.empty?
      puts 'Nothing left to download. Exiting.'
      next
    end

    dest_root = config.local_dir
    cumulative = 0
    rows.each_with_index do |row, idx|
      cumulative += row.bytes
      local_note = Extractions.downloaded?(dest_root, row.folder) ? '  [already local]' : ''
      puts format(
        '%<idx>3d. %<size>12s  cum: %<cum>12s  %<files>7d files  %<folder>s%<note>s',
        idx: idx + 1,
        size: Extractions.human(row.bytes),
        cum: Extractions.human(cumulative),
        files: row.files,
        folder: row.folder,
        note: local_note
      )
      row.display_index = idx + 1
    end
    puts
    puts "TOTAL (all): #{Extractions.human(cumulative)} (#{cumulative} bytes)"
    puts

    # 4) Selection
    if config.selection.empty?
      puts <<~HELP
        Select folders to download:
          - Use numbers, commas, and ranges, e.g. 1,3-5,12
          - Or type 'all' to download all
          - Press Enter to cancel
      HELP
      print 'Your selection: '
      selection = $stdin.gets.to_s.strip
    else
      selection = config.selection
      puts "Selection from env: #{selection}"
    end

    if selection.empty?
      puts 'No selection. Exiting.'
      next
    end

    idxs = Extractions::Selector.parse(selection, max: rows.size)
    if idxs.empty?
      puts 'No valid indices. Exiting.'
      next
    end

    chosen       = rows.select { |r| idxs.include?(r.display_index) }
    chosen_bytes = chosen.sum(&:bytes)
    puts
    puts "Selected #{chosen.size} folder(s), total #{Extractions.human(chosen_bytes)}"
    puts

    # 5) Download, one folder at a time to stay gentle on the production volume
    FileUtils.mkdir_p(dest_root)
    downloader = Extractions::Downloader.new(config, kubectl, pod)
    puts "Downloading to: #{File.expand_path(dest_root)}"

    skipped = 0
    chosen.each_with_index do |row, idx|
      puts "\n→ [#{idx + 1}/#{chosen.size}] #{row.folder}  (#{Extractions.human(row.bytes)})"

      if !config.force? && Extractions.downloaded?(dest_root, row.folder)
        puts '  already local, skipping'
        skipped += 1
        next
      end

      downloader.download(row, dest_root)
    end

    puts
    if skipped.positive?
      puts "Skipped #{skipped} folder(s) already present locally. " \
           'Re-run with FORCE=true to replace them.'
    end
    puts "\nDone."
  end
  # rubocop:enable Metrics/BlockLength
end

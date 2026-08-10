# frozen_string_literal: true

module Extraction
  # Iterates the on-disk records written by the previous preprocess block.
  # Yields (document, page) exactly like SjApiEnrichmentIterator so the
  # enrichment-style execution can consume either source unchanged.
  #
  # The writer (TransformationWorker via PreProcess::Output#write_page) names
  # files after its own extraction page number, so the stored page numbers can
  # be sparse (e.g. 1, 101, 201). We therefore enumerate the files that
  # actually exist, in embedded-page-number order, and yield each with a dense
  # sequential index — which is what the consumer's page_from_index math needs.
  class PreProcessRecordIterator
    # @param pages [Integer, nil] how many stored pages to yield, nil for all of them.
    #   A sample extraction takes the first page only.
    def initialize(folder, pages: nil)
      @folder = folder
      @pages = pages
    end

    def each
      document_paths.each_with_index do |path, index|
        yield(Extraction::Document.load_from_file(path), index + 1)
      end
    end

    private

    def document_paths
      paths = Dir.glob("#{@folder}/**/*.json").sort_by { |path| embedded_page_number(path) }
      @pages.present? ? paths.first(@pages) : paths
    end

    def embedded_page_number(path)
      File.basename(path, '.json').split('__').last.to_i
    end
  end
end

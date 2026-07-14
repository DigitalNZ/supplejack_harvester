# frozen_string_literal: true

module Extraction
  # Iterates the on-disk records written by the previous preprocess block.
  # Yields (document, page) exactly like SjApiEnrichmentIterator so the
  # enrichment-style execution can consume either source unchanged.
  class PreProcessRecordIterator
    def initialize(folder)
      @documents = Extraction::Documents.new(folder)
    end

    def each
      (1..@documents.total_pages).each do |page|
        yield(@documents[page], page)
      end
    end
  end
end

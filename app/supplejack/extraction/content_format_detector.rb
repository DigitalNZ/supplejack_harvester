# frozen_string_literal: true

module Extraction
  # Utility methods for detecting document content formats (JSON, XML, HTML)
  # These are stateless helper methods used during extraction to determine
  # the actual format of content regardless of what was configured.
  module ContentFormatDetector
    module_function

    def xml_sitemap?(stripped_body, body)
      stripped_body.start_with?('<?xml') ||
        (stripped_body.start_with?('<') && (body.include?('<urlset') || body.include?('<sitemap')))
    end

    def html_content?(body)
      body.include?('<html') || body.include?('<!DOCTYPE') || body.include?('<')
    end

    # rubocop:disable Metrics/CyclomaticComplexity
    def detect_from_content(stripped_body)
      return 'XML' if xml_format?(stripped_body)
      return 'JSON' if json_format?(stripped_body)
      return 'HTML' if html_format?(stripped_body)

      'HTML' # Default
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    def xml_format?(stripped_body)
      stripped_body.start_with?('<?xml') ||
        (stripped_body.start_with?('<') && stripped_body.include?('<?xml'))
    end

    def json_format?(stripped_body)
      stripped_body.start_with?('{', '[')
    end

    def html_format?(stripped_body)
      stripped_body.include?('<html') || stripped_body.include?('<!DOCTYPE') || stripped_body.include?('<')
    end
  end
end


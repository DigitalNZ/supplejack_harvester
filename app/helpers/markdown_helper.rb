# frozen_string_literal: true

# Renders the markdown people write in free text fields, currently pipeline descriptions.
#
# Two layers keep the output narrow. Commonmarker escapes any raw HTML that was typed rather
# than passing it through, and the allow list below is the single statement of which formatting
# we support. Tables are an extension we leave switched off, so their pipes stay literal text.
# Headings and images are core markdown and cannot be switched off, so they are parsed and then
# stripped back to the text they wrap.
module MarkdownHelper
  ALLOWED_TAGS = %w[p br strong em del code pre a ul ol li blockquote hr].freeze

  # start keeps a list that begins at 3 numbered from 3, target and rel come from the pass that
  # sends links to a new tab.
  ALLOWED_ATTRIBUTES = %w[href title start target rel].freeze

  OPTIONS = {
    render: { unsafe: false, hardbreaks: true },
    extension: { strikethrough: true, autolink: true, table: false, header_ids: nil }
  }.freeze

  def markdown(text)
    return if text.blank?

    html = Commonmarker.to_html(text, options: OPTIONS, plugins: { syntax_highlighter: nil })

    sanitize(rewrite_links_and_images(html), tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRIBUTES)
  end

  private

  # Descriptions link out to wikis and documentation, so keep the pipeline the reader came from.
  #
  # Images we do not support, and stripping the tag would take its alt text with it and leave an
  # empty paragraph behind, so swap each one for the words that described it.
  def rewrite_links_and_images(html)
    fragment = Nokogiri::HTML5.fragment(html)

    fragment.css('a').each do |link|
      link['target'] = '_blank'
      link['rel'] = 'noopener noreferrer'
    end

    fragment.css('img').each do |image|
      image.replace(Nokogiri::XML::Text.new(image['alt'].to_s, fragment.document))
    end

    fragment.to_html
  end
end

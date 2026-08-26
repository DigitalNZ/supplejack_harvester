# frozen_string_literal: true

# The markdown people write in free text fields, currently pipeline descriptions, turned into the
# small set of HTML we are willing to show.
#
# Two layers keep the output narrow. Commonmarker escapes any raw HTML that was typed rather than
# passing it through, and ALLOWED_TAGS is the single statement of which formatting we support.
# Tables are an extension we leave switched off, so their pipes stay literal text. Headings and
# images are core markdown and cannot be switched off, so they are rewritten into something we do
# allow before the allow list would drop them.
#
# Sanitizing is left to the caller, since that is a view concern - see MarkdownHelper#markdown.
class Markdown
  ALLOWED_TAGS = %w[p br strong em del code pre a ul ol li blockquote hr].freeze

  # start keeps a list that begins at 3 numbered from 3, target and rel come from the pass that
  # sends links to a new tab.
  ALLOWED_ATTRIBUTES = %w[href title start target rel].freeze

  OPTIONS = {
    render: { unsafe: false, hardbreaks: true },
    extension: { strikethrough: true, autolink: true, table: false, header_ids: nil }
  }.freeze

  def initialize(text)
    @text = text
  end

  def to_html
    return if @text.blank?

    open_links_in_a_new_tab
    replace_images_with_their_alt_text
    demote_headings

    fragment.to_html
  end

  private

  def fragment
    @fragment ||= Nokogiri::HTML5.fragment(
      Commonmarker.to_html(@text, options: OPTIONS, plugins: { syntax_highlighter: nil })
    )
  end

  # Descriptions link out to wikis and documentation, so keep the pipeline the reader came from.
  def open_links_in_a_new_tab
    fragment.css('a').each do |link|
      link['target'] = '_blank'
      link['rel'] = 'noopener noreferrer'
    end
  end

  # Dropping the tag would take its alt text with it and leave an empty paragraph behind, so swap
  # each image for the words that described it.
  def replace_images_with_their_alt_text
    fragment.css('img').each do |image|
      image.replace(Nokogiri::XML::Text.new(image['alt'].to_s, fragment.document))
    end
  end

  # We have no heading sizes to offer, and stripping the tag would leave the words loose between
  # paragraphs with nothing to separate them, so a heading of any level becomes a bold paragraph.
  def demote_headings
    fragment.css('h1, h2, h3, h4, h5, h6').each do |heading|
      heading.inner_html = "<strong>#{heading.inner_html}</strong>"
      heading.name = 'p'
    end
  end
end

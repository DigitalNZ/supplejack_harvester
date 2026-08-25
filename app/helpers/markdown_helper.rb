# frozen_string_literal: true

# Shows the markdown people write in free text fields. Markdown does the rendering, this adds the
# sanitizing, which belongs here because it is the view that decides what is safe to show.
module MarkdownHelper
  def markdown(text)
    html = Markdown.new(text).to_html

    return if html.blank?

    sanitize(html, tags: Markdown::ALLOWED_TAGS, attributes: Markdown::ALLOWED_ATTRIBUTES)
  end
end

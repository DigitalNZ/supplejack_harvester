# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MarkdownHelper do
  describe '#markdown' do
    it 'returns nil when there is nothing to render' do
      expect(markdown(nil)).to be_nil
      expect(markdown('')).to be_nil
    end

    it 'renders paragraphs' do
      expect(markdown('Some context')).to include '<p>Some context</p>'
    end

    it 'keeps single line breaks the author typed' do
      expect(markdown("first\nsecond")).to include '<br>'
    end

    it 'renders bold, italic, strikethrough and inline code' do
      html = markdown('**bold** *italic* ~~gone~~ `code`')

      expect(html).to include '<strong>bold</strong>'
      expect(html).to include '<em>italic</em>'
      expect(html).to include '<del>gone</del>'
      expect(html).to include '<code>code</code>'
    end

    it 'renders bullet and numbered lists, keeping the number a list starts at' do
      expect(markdown("- one\n- two")).to include '<ul>'
      expect(markdown("3. three\n4. four")).to include '<ol start="3">'
    end

    it 'renders block quotes, horizontal rules and code blocks' do
      expect(markdown('> quoted')).to include '<blockquote>'
      expect(markdown('---')).to include '<hr>'
      expect(markdown("```\nputs 1\n```")).to include '<pre>'
    end

    it 'renders links, and opens them in a new tab' do
      html = markdown('[wiki](https://example.com/wiki)')

      expect(html).to include '<a href="https://example.com/wiki"'
      expect(html).to include 'target="_blank"'
      expect(html).to include 'rel="noopener noreferrer"'
    end

    it 'links bare urls' do
      expect(markdown('See https://example.com/wiki')).to include '<a href="https://example.com/wiki"'
    end

    it 'strips headings back to their text' do
      html = markdown('# Overview')

      expect(html).not_to include '<h1'
      expect(html).to include 'Overview'
    end

    it 'strips images back to their alt text' do
      html = markdown('![a diagram](https://example.com/diagram.png)')

      expect(html).not_to include '<img'
      expect(html).not_to include 'diagram.png'
      expect(html).to include 'a diagram'
    end

    it 'leaves table pipes as the text they were typed as' do
      html = markdown("| a | b |\n|---|---|\n| 1 | 2 |")

      expect(html).not_to include '<table'
      expect(html).to include '| a | b |'
    end

    it 'escapes raw html rather than rendering it' do
      html = markdown('<script>alert(1)</script><b>bold</b>')

      expect(html).not_to include '<script'
      expect(html).not_to include '<b>'
    end

    it 'drops links that would run javascript' do
      expect(markdown('[click](javascript:alert(1))')).not_to include 'javascript'
    end
  end
end

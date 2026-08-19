module Docs
  class Kotlin
    class CleanHtmlFilter < Filter
      def call
        subpath.start_with?('api') ? api_page : doc_page
        doc
      end

      def doc_page
        css('.page-link-to-github', '.last-modified').remove

        css('a > img').each do |node|
          node.parent.before(node.parent.content).remove
        end

        label_tabs
        format_code_blocks
      end

      def api_page
        css('.anchor-icon', '.copy-icon', '.copy-popup-wrapper', '.source-link-wrapper',
            '.navigation-controls', '.top-right-position').remove

        # The "Members"/"Members & Extensions" buttons only toggle rows via JavaScript,
        # so they render as stray text. Drop them and keep every row, which leaves the
        # "Members & Extensions" superset on display.
        css('.tabs-section').remove

        collapse_platform_tabs
        flatten_platform_tags
        promote_member_names
        format_signatures
        format_code_blocks('kotlin')

        # Dokka wraps the title in nested spans.
        if h1 = at_css('h1')
          h1.content = h1.content.strip
        end

        css('a[href="#"]').each do |node|
          node.before(node.content).remove
        end
      end

      private

      # The guide's tab strips keep their labels in data-title and only reveal panels
      # with JavaScript, so every panel renders and the reader gets the same snippet
      # two or three times with nothing to tell the variants apart.
      def label_tabs
        css('.tabs__content').each do |panel|
          title = panel['data-title']
          next if title.nil? || title.empty?

          heading = Nokogiri::XML::Node.new('h4', doc.document)
          heading.content = title
          panel.prepend_child(heading)
        end
      end

      # Every declaration is repeated once per target (Common/JVM/JS/Native/Wasm).
      # Without the tab JavaScript all copies would render stacked, so keep the
      # default one and list the targets it applies to.
      def collapse_platform_tabs
        css('.platform-hinted').each do |group|
          next if detached?(group)

          variants = group.element_children.select { |node| has_class?(node, 'sourceset-dependent-content') }
          active = variants.find { |node| node.key?('data-active') } || variants.first

          if row = group.element_children.find { |node| has_class?(node, 'platform-bookmarks-row') }
            platforms = row.css('.platform-bookmark').map { |node| node.content.strip }.uniq
            if platforms.length > 1
              row.replace(platform_note(platforms))
            else
              row.remove
            end
          end

          (variants - [active]).each(&:remove)
        end
      end

      # Dokka styles .platform-tag as inline chips. Without its CSS each one becomes
      # its own line, turning every package row into a column of target names.
      def flatten_platform_tags
        css('.platform-tags').each do |group|
          tags = group.css('.platform-tag').map { |node| node.content.strip }.uniq
          next if tags.empty?

          wrapper = group.parent
          target = wrapper && has_class?(wrapper, 'platform-tags--wrapper') ? wrapper : group
          target.replace(platform_note(tags))
        end
      end

      # Each member or package is a table row whose name cell is a bare link, so the
      # name reads as body text and the page gets no outline. Rows carrying neither a
      # signature nor a description (Inheritors, Constructors) are plain link lists
      # and are left alone.
      def promote_member_names
        css('.table-row').each do |row|
          next unless row.at_css('.title') || row.at_css('.brief-comment')

          subrow = row.at_css('.main-subrow')
          cell = subrow && subrow.element_children.first
          next unless cell && (link = cell.at_css('a'))

          heading = Nokogiri::XML::Node.new('h3', doc.document)
          heading.add_child(link)
          cell.inner_html = ''
          cell.add_child(heading)
        end
      end

      def format_signatures
        css('.symbol.monospace').each do |node|
          node.name = 'pre'
          node['data-language'] = 'kotlin'
          # Prism re-highlights pre[data-language] client-side and would drop any
          # markup anyway, so reduce the signature to plain text.
          node.content = text_with_breaks(node).squeeze(' ').strip
          node.remove_attribute('class')
        end
      end

      # Guide code blocks are already turned into pre[data-language] by the scraper's
      # parse hook, so never overwrite a language that has been established.
      def format_code_blocks(default_language = nil)
        css('pre > code').each do |node|
          pre = node.parent
          next if pre.key?('data-language')

          language = node['class'].to_s[/\blang-([\w-]+)\b/, 1] || default_language
          pre['data-language'] = language if language
          pre.content = text_with_breaks(node)
          pre.remove_attribute('class')
        end
      end

      # KDoc samples break lines with <br>, which Node#content drops, running the
      # lines together.
      def text_with_breaks(node)
        return node.content unless node.inner_html.include?('<br')
        Nokogiri::HTML.fragment(node.inner_html.gsub(%r{<br\s*/?>}i, "\n")).content
      end

      def platform_note(labels)
        note = Nokogiri::XML::Node.new('p', doc.document)
        bold = Nokogiri::XML::Node.new('b', doc.document)
        bold.content = 'Platforms:'
        note.add_child(bold)
        note.add_child(doc.document.create_text_node(" #{labels.join(', ')}"))
        note
      end

      # Node#matches? searches the whole document, which is ~40ms a call on the big
      # package pages.
      def has_class?(node, name)
        node['class'].to_s.split.include?(name)
      end

      # Removing a variant detaches any nested groups still queued for processing.
      def detached?(node)
        !node.ancestors.include?(doc)
      end
    end
  end
end

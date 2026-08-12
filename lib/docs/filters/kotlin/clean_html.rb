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

      # Every declaration is repeated once per target (Common/JVM/JS/Native/Wasm).
      # Without the tab JavaScript all copies would render stacked, so keep the
      # default one and list the targets it applies to.
      def collapse_platform_tabs
        css('.platform-hinted').each do |group|
          next if detached?(group)

          variants = group.element_children.select { |node| node.matches?('.sourceset-dependent-content') }
          active = variants.find { |node| node.key?('data-active') } || variants.first

          if row = group.element_children.find { |node| node.matches?('.platform-bookmarks-row') }
            platforms = row.css('.platform-bookmark').map { |node| node.content.strip }.uniq
            if platforms.length > 1
              row.replace("<p><b>Platforms:</b> #{platforms.join(', ')}</p>")
            else
              row.remove
            end
          end

          (variants - [active]).each(&:remove)
        end
      end

      # On class and package pages each member is a table row whose name cell is a
      # bare link, so the name reads as body text and the page gets no outline.
      # Rows without a .title cell (Inheritors, Constructors lists) are just link
      # lists and are left alone.
      def promote_member_names
        css('.table-row .main-subrow').each do |subrow|
          next unless subrow.at_css('.title')

          cell = subrow.element_children.first
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
          node.content = node.content.squeeze(' ').strip
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
          pre.content = node.content
          pre.remove_attribute('class')
        end
      end

      # Removing a variant detaches any nested groups still queued for processing.
      def detached?(node)
        !node.ancestors.include?(doc)
      end
    end
  end
end

module Docs
  class Kotlin
    class EntriesFilter < Docs::EntriesFilter
      # Breadcrumbs are empty on the module page and could be short on any page Dokka
      # renders differently, so never index a blank name or type: Entry rejects both.
      def get_name
        return heading_text unless api_page?

        # ['kotlin-stdlib', 'kotlin.collections', 'List', 'size'] => 'kotlin.collections.List.size'
        api_breadcrumbs.drop(1).join('.').presence || heading_text
      end

      def get_type
        return doc_breadcrumbs.first.presence || 'Language guide' unless api_page?

        api_breadcrumbs[1].presence || api_breadcrumbs.first.presence || 'kotlin-stdlib'
      end

      private

      def heading_text
        node = at_css('h1') || at_css('h2')
        node && node.content.strip.squish
      end

      def api_page?
        subpath.start_with?('api')
      end

      # Dokka renders the trailing crumb as a <span class="current"> rather than a link.
      def api_breadcrumbs
        @api_breadcrumbs ||= css('.breadcrumbs a, .breadcrumbs .current').map { |node| node.content.strip }
      end

      def doc_breadcrumbs
        @doc_breadcrumbs ||= begin
          body = doc.document.at_css('body')
          body && body['data-breadcrumbs'].to_s.split('///').map(&:strip) || []
        end
      end
    end
  end
end

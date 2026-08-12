module Docs
  class Kotlin
    class EntriesFilter < Docs::EntriesFilter
      def get_name
        if api_page?
          # ['kotlin-stdlib', 'kotlin.collections', 'List', 'size'] => 'kotlin.collections.List.size'
          api_breadcrumbs[1..-1].join('.')
        else
          node = at_css('h1') || at_css('h2')
          node && node.content.strip.squish
        end
      end

      def get_type
        if api_page?
          api_breadcrumbs[1]
        else
          doc_breadcrumbs.first.presence || 'Language guide'
        end
      end

      private

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

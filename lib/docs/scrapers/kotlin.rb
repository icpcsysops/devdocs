module Docs
  class Kotlin < UrlScraper
    SITEMAP_URL = 'https://kotlinlang.org/sitemap.xml'

    self.type = 'kotlin'
    self.base_url = 'https://kotlinlang.org/'
    self.links = {
      home: 'https://kotlinlang.org/',
      code: 'https://github.com/JetBrains/kotlin'
    }

    html_filters.push 'kotlin/entries', 'kotlin/clean_html'

    # The stdlib reference is Dokka-generated and lives in #content; the language
    # guide is a regular kotlin-web-site article.
    options[:container] = ->(filter) { filter.subpath.start_with?('api') ? '#content' : 'article' }

    options[:skip_patterns] = [/kotlin-stdlib\/org\./]

    # home.html is a redirect stub with no <article>; the rest are non-reference pages.
    options[:skip] = %w(
      docs/home.html
      docs/books.html
      docs/eap.html
      docs/videos.html
      docs/events.html
      docs/resources.html
      docs/reference/grammar.html)

    options[:fix_urls] = ->(url) do
      url.sub! %r{/docs/reference/}, '/docs/'
      url
    end

    options[:attribution] = <<-HTML
      &copy; 2010&ndash;2026 JetBrains s.r.o. and Kotlin Programming Language contributors<br>
      Licensed under the Apache License, Version 2.0.
    HTML

    # The current release is served from the unversioned path; older releases are
    # archived under /api/core/<version>/. Both use the same Dokka layout.
    def self.stdlib(path_version = nil)
      dir = path_version ? "api/core/#{path_version}/kotlin-stdlib/" : 'api/core/kotlin-stdlib/'
      self.root_path = "#{dir}index.html"
      options[:only_patterns] = [/\A#{Regexp.escape(dir)}/]
      options[:skip] += ["#{dir}all-types.html"]

      # kotlinlang.org only publishes the guide for the current release, so pair it
      # with the unversioned API reference.
      options[:only_patterns] << /\Adocs\// if path_version.nil?
    end

    version do
      stdlib
      self.release = '2.4.10'
    end

    version '2.3' do
      stdlib '2.3'
      self.release = '2.3.0'
    end

    version '2.2' do
      stdlib '2.2'
      self.release = '2.2.0'
    end

    version '2.1' do
      stdlib '2.1'
      self.release = '2.1.0'
    end

    version '2.0' do
      stdlib '2.0'
      self.release = '2.0.0'
    end

    version '1.9' do
      stdlib '1.9'
      self.release = '1.9.0'
    end

    def get_latest_version(opts)
      get_latest_github_release('JetBrains', 'kotlin', opts)
    end

    # The guide's navigation is rendered client-side and the Dokka pages only link
    # to a handful of its pages, so seed the crawl from the sitemap instead.
    def initial_paths
      return super if self.class.version.present?

      response = Request.run(SITEMAP_URL)
      return super unless response.success?

      paths = response.body.scan(%r{<loc>\s*https://kotlinlang\.org/(docs/[^\s<]+\.html)\s*</loc>}).flatten.uniq
      # :skip only filters crawled links, so it has to be applied to seeds by hand.
      # Read it off the class: the instance-level options are built from initial_paths.
      paths - self.class.options[:skip]
    end

    private

    def process_response?(response)
      return false unless super
      response.body !~ /http-equiv="refresh"/i
    end

    def parse(response)
      response.body.gsub! %r{<div\ class="code-block" data-lang="([^"]+)"[^>]*>([\W\w]+?)</div>}, '<pre class="code" data-language="\1">\2</pre>'
      super
    end
  end
end

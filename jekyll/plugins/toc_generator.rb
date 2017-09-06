require 'yaml'
require 'json'
require 'kramdown'

class TocPage < Jekyll::Page
  # Initialize a new RedirectPage.
  #
  # site - The Site object.
  # base - The String path to the source.
  # dir  - The String path between the source and the file.
  # name - The String filename of the file.
  def initialize(site, base, dir, name, content)
    @site = site
    @base = base
    @dir = dir
    @name = name
    @content = @output = content

    self.process(name)
    self.data = {}
  end
end

class TocGenerator < Jekyll::Generator

  ITEM_TYPE_HEADER = 'header'
  ITEM_TYPE_PLACEHOLDER = 'placeholder'

  def generate(site)
    toc_output = site.config['toc_output'] || 'HelpTOC.json'

    # This comes from toc_builder_hook.rb
    toc_content = site.data['toc']
    toc_page = TocPage.new(site, site.source, '/', toc_output, toc_content.to_json)
    site.pages << toc_page

    populate_prev_next(site, toc_content)
  end

  def populate_prev_next(site, toc)
    hash = Hash.new
    site.pages.each { |p| hash[p.path] = p }
    missing_titles = Set.new
    do_populate_prev_next(hash, toc, missing_titles)
    missing_titles.each do |x|
        puts "Page is missing titles for next/prev navigation: #{x}"
    end
    raise "Site has missing #{missing_titles.count} missing titles" if not missing_titles.empty?
  end

  def do_populate_prev_next(pages, toc, missing_titles)
      p = nil
      toc.each_with_index do |t,i|
          j = i + 1
          n = toc[j] if j < toc.length
          while j < toc.length and not n.nil? and not n.key?(:path) do
              j = j + 1
              n = toc[j]
          end

          if t.key?(:path)
              this_page = pages[t[:path]]

              this_page.data["previous"] = pages[p[:path]] unless p.nil?
              this_page.data["next"] = pages[n[:path]] unless n.nil?

              raise "Unknown page: #{n.inspect}" if not n.nil? and pages[n[:path]].nil?

              missing_titles << p[:path] if not p.nil? and not pages[p[:path]].data.key?("title")
              missing_titles << n[:path] if not n.nil? and not pages[n[:path]].data.key?("title")

              do_populate_prev_next(pages, t[:pages], missing_titles) if t.key?(:pages)

              p = t
          end
      end
  end
end

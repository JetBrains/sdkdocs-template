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
    toc_input = site.config['toc_input'] || '_SUMMARY.md'
    toc_output = site.config['toc_output'] || 'HelpTOC.json'

    # Read toc_input, generate an object model, convert it to JSON and save to
    # a Page named from toc_output
    toc_content = generate_toc(site, toc_input)
    toc_page = TocPage.new(site, site.source, '/', toc_output, toc_content.to_json)
    site.pages << toc_page

    populate_prev_next(site, toc_content)
  end

  def generate_toc(site, toc_input)

    toc = []
    content = File.read(File.join(site.source, toc_input))
    kramdown_config = site.config['kramdown'].merge({:html_to_native => true})
    kramdown_doc = Kramdown::Document.new(content, kramdown_config)

    kramdown_doc.root.children.each do |c|
      item = extract_from_node(c)
      toc.concat(item) if item != nil
    end

    # Removing headers of empty sections
    delete_list = []
    (0).upto(toc.length-1) do |i|
      item = toc[i]
      prev = toc[i-1] != nil ? toc[i-1] : nil
      item_is_header = (item[:type] != nil and item[:type] == ITEM_TYPE_HEADER)
      prev_is_header = (prev != nil and prev[:type] != nil and prev[:type] == ITEM_TYPE_HEADER)

      if item_is_header and prev_is_header
        delete_list.push(i-1)
      end
    end

    delete_list.each do |del_index|
      toc.delete_at(del_index)
    end

    toc
  end

  def populate_prev_next(site, toc)
    hash = Hash.new
    site.pages.each { |p| hash[p.path] = p }
    missing_titles = Set.new
    do_populate_prev_next(hash, toc, missing_titles)
    missing_titles.each do |x|
        puts "Page is missing titles for next/prev navigation: #{x}"
    end
    raise "Site has missing titles" if not missing_titles.empty?
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

  private
  def extract_from_node(node)
    items = []

    case node.type
      when :ul
        items.concat(extract_items(node))

      when :header
        items.push(extract_header(node)) if node.options[:level] == 2
    end

    return items.length > 0 ? items : nil
  end

  def extract_items(ul_node)
    items = []

    ul_node.children.select { |n| n.type == :li }.each do |li_node|
      items.push(extract_item(li_node))
    end

    return items
  end

  def extract_item(li_node)
    item = {}

    p = li_node.children[0]
    case p.children[0].type
      when :text
        item[:title] = p.children[0].value.strip
        item[:type] = ITEM_TYPE_PLACEHOLDER

      when :a
        a = p.children[0]
        href = a.attr['href']
        basename = href.chomp(File.extname(href)).sub(/^\//,'')
        href = basename + '.html'
        item[:id] = basename
        item[:title] = get_text(a.children)
        item[:url] = href
        item[:path] = a.attr['href']
        is_external = href.start_with?('http://', 'https://', 'ftp://', '//')
        item[:is_external] = true if is_external
    end

    li_node.children.drop(1).each do |child|
      pages = extract_items(child) if child.type == :ul
      item[:pages] = pages if pages != nil
    end

    return item
  end

  def get_text(nodes)
    nodes.reduce('') { |t, c| t + format(c.value) }
  end

  def format(item)
    case item
      when Symbol
        Kramdown::Utils::Entities.entity(item.to_s).char
      when String
        item
    end
  end

  def extract_header(header_node)
    return {
      :title => header_node.options[:raw_text].strip,
      :type => ITEM_TYPE_HEADER
    }
  end
end

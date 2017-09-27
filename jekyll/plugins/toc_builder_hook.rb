require 'yaml'
require 'json'
require 'kramdown'

Jekyll::Hooks.register :site, :post_read do |site|
  toc_input = site.config['toc_input'] || '_SUMMARY.md'
  builder = TocContentBuilder.new
  toc_content = builder.build_toc(site, toc_input)
  site.data['toc'] = toc_content
end

class TocContentBuilder

  def build_toc(site, toc_input)

    toc = []
    content = File.read(File.join(site.source, toc_input))
    kramdown_config = site.config['kramdown'].merge({:html_to_native => true})
    kramdown_doc = Kramdown::Document.new(content, kramdown_config)

    parent_id = nil
    kramdown_doc.root.children.each do |c|
      item = extract_from_node(c, parent_id)
      if not item.nil? then
        toc.concat(item)
        parent_id = item[0][:id] if item[0][:type] == :header
      end
    end

    # Removing headers of empty sections
    delete_list = []
    (0).upto(toc.length-1) do |i|
      item = toc[i]
      prev = toc[i-1] != nil ? toc[i-1] : nil
      item_is_header = (item[:type] != nil and item[:type] == :header)
      prev_is_header = (prev != nil and prev[:type] != nil and prev[:type] == :header)

      if item_is_header and prev_is_header
        delete_list.push(i-1)
      end
    end

    delete_list.each do |del_index|
      toc.delete_at(del_index)
    end

    toc
  end

  private
  def extract_from_node(node, parent_id)
    items = []

    case node.type
      when :ul
        items.concat(extract_items(node, parent_id))

      when :header
        items.push(extract_header(node)) if node.options[:level] == 2
    end

    return items.length > 0 ? items : nil
  end

  def extract_items(ul_node, parent_id = nil)
    items = []

    ul_node.children.select { |n| n.type == :li }.each do |li_node|
      items.push(extract_item(li_node, parent_id))
    end

    return items
  end

  def extract_item(li_node, parent_id)
    item = {}
    item[:parent_id] = parent_id unless parent_id.nil?

    p = li_node.children[0]
    case p.children[0].type
      when :text
        title = p.children[0].value.strip
        item[:id] = title.gsub(' ', '_')
        item[:title] = title
        item[:type] = :placeholder

      when :a
        a = p.children[0]
        href = a.attr['href']
        is_external = href.start_with?('http://', 'https://', 'ftp://', '//')
        if not is_external then
            basename = href.chomp(File.extname(href)).sub(/^\//,'')
            href = basename + '.html'
        end
        item[:id] = basename
        item[:title] = get_text(a.children)
        item[:url] = href
        item[:path] = a.attr['href']
        item[:is_external] = true if is_external
    end

    li_node.children.drop(1).each do |child|
      pages = extract_items(child, item[:id]) if child.type == :ul
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
    title = header_node.options[:raw_text].strip
    return {
      :id => title.gsub(' ', '_'),
      :title => title,
      :type => :header
    }
  end
end

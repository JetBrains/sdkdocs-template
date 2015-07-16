require 'nokogiri'
require 'uri'

# The class name and filename are important! Alphabetically after post_filters.rb...
class PostLinkChecker < Jekyll::SiteFilter

  def post_render(site)

    known_files = []
    site.pages.each do |p|
      known_files.push post_output_path(p)
    end
    site.static_files.each do |f|
      known_files.push f.relative_path
    end

    html_docs = {}
    site.pages.select { |p| p.output_ext == '.html' }.each do |post|
      html = Nokogiri::HTML(post.output)
      target_path = post_output_path(post)
      html_docs[target_path.to_s] = {
        :html => html,
        :anchor_targets => anchor_targets(html)
      }
    end

    site.pages.select { |p| p.output_ext == '.html' }.each do |post|
      errors = []

      html_doc = html_docs[post_output_path(post)]
      html = html_doc[:html]
      anchor_targets = html_doc[:anchor_targets]

      links = html.css('a').each do |a|
        href = a['href']

        next if (href.nil? and not a['name'].nil?) or href.start_with?('//')

        if href.to_s.empty? then
          errors.push "Link points to empty string: #{a}"
          next
        end

        url = URI.parse(href)
        next unless is_local_link(url)

        path = url.path
        fragment = url.fragment

        if path.to_s.empty? and not fragment.to_s.empty? then
          errors.push "Unknown anchor (current page): #{a}" unless anchor_targets.include?(fragment)
          next
        end

        next if path == '/'

        target_path = Pathname.new(File.join('/', File.dirname(post.path))) + Pathname.new(path)

        if not known_files.include?(target_path.to_s) then
          errors.push "Unknown file: #{a}" unless known_files.include?(target_path.to_s)
          next
        end

        if not target_path.to_s.empty? and not fragment.to_s.empty? then

          puts "Looking for fragment <#{fragment}> in file <#{target_path}>"

          candidate_anchor_targets = html_docs[target_path.to_s][:anchor_targets]
          errors.push "Unknown anchor (other page): #{a}" unless candidate_anchor_targets.include?(fragment)
        end
      end

      images = html.css('img').each do |img|
        src = img['src']

        target_src = Pathname.new(File.join('/', File.dirname(post.path))) + Pathname.new(src)

        errors.push "Unknown image: #{img}" unless known_files.include?(target_src.to_s)
      end

      if errors.any?
        puts "Errors with links in #{post.path}:"
        errors.each { |e| puts "  #{e}" }
      end
    end
  end

  def is_local_link(url)
    (url.scheme == '' or url.scheme.nil?)
  end

  def post_output_path(post)
    '/' + post.path.chomp(post.ext) + post.output_ext
  end

  def anchor_targets(html)
    targets = []
    html.css('a').each do |a|
      name = a['name']
      targets.push(name) unless name.to_s.empty?
    end
    targets
  end
end

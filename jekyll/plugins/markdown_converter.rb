require 'kramdown'
require 'rouge'
require 'uri'

module Jekyll
  module Converters
    class Markdown
      class CustomKramdownParser
        def initialize(config)
          @config = config
        end

        def convert(content)
          options = Utils.symbolize_hash_keys(@config['kramdown'])
          options[:baseurl] = @config['baseurl']
          options[:upsource] = Utils.symbolize_hash_keys(@config['upsource'])
          Kramdown::Document.new(content, options).to_upsrc
        end
      end
    end
  end
end

module Kramdown
  module Converter
    class Upsrc < Html

      def convert_header(el, indent)
        attr = el.attr.dup
        el_id = generate_id(el.options[:raw_text])

        if @options[:auto_ids] && !attr['id']
          attr['id'] = el_id
        end
        @toc << [el.options[:level], el_id, el.children] if el_id && in_toc?(el)
        level = output_header_level(el.options[:level])

        if level <= 3
          anchor = Element.new(:a, nil, {'href' => '#' + el_id, 'class' => 'anchor-link'})
          el.children.push(anchor)
        end

        anchor = format_as_block_html("a", {'name' => el_id, 'class' => 'elem-anchor'}, inner(Element.new(:a, nil), indent), indent)
        header = format_as_block_html("h#{level}", attr, inner(el, indent), indent)
        anchor + header
      end

      # Convert a <code> block
      # Overrides Html#convert_codeblock to support highlighting lines in the class
      # attribute (class="csharp{1-3}") and to change the generated elements and attributes
      # to use expected webhelp values
      def convert_codeblock(el, indent)
        attr = el.attr.dup
        lang = self.extract_code_language(attr) || 'text'
        highlight_lines = ''

        if attr['class'] and attr['class'].scan(/\{[\d\-\,]+\}/).length > 0
          lang_parts = attr['class'].split('{')
          highlight_lines = "{#{lang_parts[1]}"
        end

        div_attr = {}
        div_attr['class'] = "code-block"
        div_attr['data-lang'] = lang if lang

        code = highlight_code(el.value, lang, :block, { :highlight_lines => highlight_lines })
        code_attr = {}
        code_attr['class'] = "code-block__wrapper"

        format_as_block_html('div', div_attr, format_as_span_html('code', code_attr, code), 0)
      end

      # Extract the code block/span language from the class attribute, if specified.
      # Skip any {} chars (used for highlighting lines)
      def extract_code_language(attr)
        if attr['class']
          class_attr = attr['class']

          if class_attr.scan(/\{|\}/).length > 0
            class_attr = class_attr.split('{')[0]
          end

          class_attr.scan(/\blanguage-(\w+)\b/).first.first
        end
      end

      # Convert a code span element
      # Overrides Html#convert_codespan to provide different class attributes, as the default
      # implementation only provides 'highlighter-pygments'
      def convert_codespan(el, indent)
        attr = el.attr.dup
        lang = extract_code_language!(attr) || 'text'
        result = highlight_code(el.value, lang, :span)
        attr['class'] = 'code'
        attr['class'] += " highlight language-#{lang}" if lang
        format_as_span_html('code', attr, result)
      end

      # Override Html#convert_a to identify external links. Also converts .md links to .html
      def convert_a(el, indent)
        res = inner(el, indent)
        attr = el.attr.dup
        attr['href'] = '' if attr['href'].nil?
        href = convert_href(attr['href'])

        is_external = href.start_with?('http://', 'https://', 'ftp://', '//')
        attr['data-bypass'] = 'yes' if is_external
        if href.start_with?('mailto:')
          mail_addr = href[7..-1]
          attr['href'] = obfuscate('mailto') << ":" << obfuscate(mail_addr)
          res = obfuscate(res) if res == mail_addr
        end

        href = @options[:baseurl] + href[1, href.length - 1] if href.start_with?('/') and !href.start_with?('//')
        uri = URI(href)
        uri.path = uri.path.chomp(File.extname(uri.path)) + '.html' if !uri.path.nil? and File.extname(uri.path) == '.md' and !is_external
        attr['href'] = uri.to_s
        attr['target'] = '_blank' if is_external

        format_as_span_html(el.type, attr, "<span>#{res}</span>")
      end

      # TODO: I don't really like this here. Everything else is all about converting
      # the document, and this is expanding a link href to Upsource. Not sure where
      # else to put it though, without creating some new kind of extension point,
      # which is overkill
      def convert_href(href)
        if href.start_with?('upsource://')
          opts = @options[:upsource]

          # Consider the upsource: protocol to actually be upsource://host/path, where host
          # is server, repo + commit SHA. Just like the file: protocol, the host can be
          # skipped, in which case, we'll use the values from config. Parsing the host hasn't
          # been implemented, because I'm lazy and we don't actually need it right now, but
          # will at least have the space in the URL to add it when we do.
          # This implies that the path needs to start with a slash, which in turn means *three*
          # slashes for the plain upsource: protocol - upsource:///path/to/file.java
          server = opts[:server]
          repo = opts[:repo]
          revision = if opts[:commit] == 'HEAD' then 'HEAD' else "#{repo}-#{opts[:commit]}" end
          path = href[11..-1]

          raise 'Upsource link must be in the form upsource:///path/to/file.java. Note the 3 slashes!' unless path.start_with?('/')

          # e.g. https://upsource.jetbrains.com/idea-ce/file/idea-ce-1731d054af4ca27aa827c03929e27eeb0e6a8366/platform/editor-ui-api/src/com/intellij/openapi/actionSystem/AnAction.java
          # or /file/HEAD/platform/...
          href = 'https://' + server + "/#{opts[:repo]}/file/#{revision}" + path
        end

        href
      end

      def convert_img(el, indent)
        attr = el.attr.dup
        src = attr['src']
        src = @options[:baseurl] + src[1, src.length - 1] if src.start_with?('/') and !src.start_with?('//')
        attr['src'] = src

        "<img#{html_attributes(attr)} />"
      end

      def convert_blockquote(el, indent)

        if el.children[0].type == :p and el.children[0].children[0].type == :strong
          p = el.children[0]
          type = inner_text(p.children[0], []).downcase.gsub(/\s+/, '')

          # Remove the "Note" bold text from the first paragraph
          p.children.slice!(0)

          type = type + ' ' + el.attr['class'] unless el.attr['class'].nil?
          el.attr['class'] = type

          return format_seealso(el, indent) if type == 'seealso'
        end

        format_as_indented_block_html('aside', el.attr, inner(el, indent), indent)
      end

      def inner_text(el, stack)
        result = ''
        stack.push el
        result << el.value unless el.value.nil?
        el.children.each do |inner_el|
          result << inner_text(inner_el, stack)
        end
        stack.pop
        result
      end

      def format_seealso(el, indent)
        h2 = format_as_span_html('h2', [], 'See Also')
        header = format_as_indented_block_html('div', {'class' => 'seealso__header'}, h2, indent)

        columns = ''
        column = ''
        for c in el.children do
          if c.type == :blank
            columns += format_as_indented_block_html('div', {'class' => 'seealso__col'}, column, indent) unless column == ''
            column = ''
          else
            column += convert(c, indent)
          end
        end
        columns += format_as_indented_block_html('div', {'class' => 'seealso__col'}, column, indent) unless column == ''

        content = format_as_indented_block_html('div', {'class' => 'seealso__content'}, columns, indent)
        format_as_indented_block_html('section', el.attr, header+content, indent)
      end
    end

# Rouge doesn't support highlighting lines - see jneen/rouge#264
# If/when it does, rewrite this to override the default implmentation
# from Kramdown, to pass in the line numbers to highlight. See
# kramdown/converters/syntax_highlighters/rouge.rb for the actual code
#
#    module SyntaxHighlighter
#      module Rouge
#        ::Kramdown::Converter.add_syntax_highlighter(:rouge, Rouge)
#
#        def self.call(converter, text, lang, type, code_opts)
#          # TODO: Merge this with :options below
#          opts = converter.options[:syntax_highlighter_opts].dup
#
#          hl_lines = ''
#          highlight_lines = code_opts[:highlight_lines] || ''
#          if highlight_lines
#            hl_lines = highlight_lines.gsub(/[{}]/, '').split(',').map do |ln|
#              if matches = /(\d+)-(\d+)/.match(ln)
#                ln = Range.new(matches[1], matches[2]).to_a.join(' ')
#              end
#              ln
#            end.join(' ')
#          end
#
#          if lang
#            ::Pygments.highlight(text,
#                               :lexer => lang || 'text',
#                               :options => {
#                                 :encoding => 'utf-8',
#                                 :nowrap => true,
#                                 :hl_lines => hl_lines
#                               })
#          else
#            escape_html(text)
#          end
#        end
#      end
#    end
  end

  # GFM parser doesn't support indented code blocks, i.e. those that are inside a list
  module Parser
    class GFM2 < GFM
      def parse
        super
      end

      # Note that we need to keep the same number of capturing groups
      # The parsing code relies on this order

      FENCED_CODEBLOCK_MATCH = /^([ \t]*([~`]){3,})\s*((\w+)(?:\{[\,\d\-]+\})?)?\s*?\n(.*?)^\1.*?\n/m

      define_parser(:codeblock_fenced_gfm_indented, /^[ \t]*[~`]{3,}/, nil, 'parse_codeblock_fenced')

      def initialize(source, options)
        super
        {:codeblock_fenced_gfm => :codeblock_fenced_gfm_indented}.each do |current, replacement|
          i = @block_parsers.index(current)
          @block_parsers.delete(current)
          @block_parsers.insert(i, replacement)
        end
      end

      def parse_codeblock_fenced
        if @src.check(self.class::FENCED_CODEBLOCK_MATCH)
          start_line_number = @src.current_line_number
          @src.pos += @src.matched_size
          el = new_block_el(:codeblock, unindent(@src[5]), nil, :location => start_line_number)
          lang = @src[3].to_s.strip
          unless lang.empty?
            el.options[:lang] = lang
            el.attr['class'] = "language-#{@src[4]}"
          end
          @tree.children << el
          true
        else
          false
        end
      end

      def unindent(s)
        s.gsub(/^#{s.scan(/^[ \t]*(?=\S)/).min}/, '')
      end
    end
  end
end


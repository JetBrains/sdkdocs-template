# Used by the layout to create a page_id variable from its URL
module Jekyll
  module ToIdFilter
    def to_id(input)
      input.sub(/^\//, '').sub(/.html$/, '')
    end
  end
end

Liquid::Template.register_filter(Jekyll::ToIdFilter)

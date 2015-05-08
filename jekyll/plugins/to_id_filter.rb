module Jekyll
  module ToIdFilter
    def to_id(input)
      input.sub(/^\//, '').sub(/.html$/, '')
    end
  end
end

Liquid::Template.register_filter(Jekyll::ToIdFilter)

# frozen_string_literal: true

require 'scraped'

class MemberPage < Scraped::HTML
  field :image do
    noko.css('img.img-detail/@src').text
  end

  field :source do
    url
  end
end

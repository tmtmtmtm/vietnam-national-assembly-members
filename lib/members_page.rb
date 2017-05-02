# frozen_string_literal: true

require 'scraped'

class MembersPage < Scraped::HTML
  field :members do
    noko.xpath('//div[@class="ds-list"]//table//tr[td]').map do |tr|
      fragment(tr => MemberRow).to_h
    end
  end

  field :next_page do
    noko.css('ul.paging a.next/@href').text
  end
end

class MemberRow < Scraped::HTML
  field :old_id do
    File.basename(source, '.*')
  end

  field :id do
    source.split('/').last(2).first
  end

  field :name do
    tds[1].text.tidy
  end

  field :birth_date do
    '%d-%02d-%02d' % tds[2].text.tidy.split('/').reverse
  end

  field :gender do
    gender_from(tds[3].text.tidy)
  end

  field :area do
    tds[4].text.tidy
  end

  field :term do
    '13'
  end

  field :source do
    URI.encode tds[1].css('a/@href').text
  end

  private

  def tds
    noko.css('td')
  end

  def gender_from(text)
    return if text.to_s.empty?
    return 'female' if text == 'Nữ'
    return 'male' if text == 'Nam'
    abort "Unknown gender: #{text}"
  end
end

#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'colorize'
require 'pry'
# require 'open-uri/cached'
# OpenURI::Cache.cache_path = '.cache'
require 'scraped_page_archive/open-uri'

class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def gender_from(text)
  return if text.to_s.empty?
  return 'female' if text == 'Nữ'
  return 'male' if text == 'Nam'
  abort "Unknown gender: #{text}"
end

# We will want to actually scrape the data from these at some point, but
# for now we only archive it, in case it disappears
def archive_committees(url)
  noko = noko_for(url)
  urls = noko.css('a[href^="http://dbqh.na.gov.vn/cac-co-quan-quoc-hoi/"]/@href').map(&:text)
  raise "Can't find any committees" if urls.empty?
  urls.each do |c_url|
    warn "Archiving committee at #{c_url}"
    open(url)
  end
end

def scrape_list(url)
  warn url
  noko = noko_for(url)

  noko.xpath('//div[@class="ds-list"]//table//tr[td]').each do |tr|
    tds = tr.css('td')
    person_link = URI.encode tds[1].css('a/@href').text
    data = { 
      id: File.basename(person_link,'.*'),
      name: tds[1].text.tidy,
      birth_date: '%d-%02d-%02d' % tds[2].text.tidy.split("/").reverse,
      gender: gender_from(tds[3].text.tidy),
      area: tds[4].text.tidy,
      source: person_link,
      term: '13',
    }.merge(scrape_person(person_link))
    ScraperWiki.save_sqlite([:id, :term], data)
  end

  unless (next_page = noko.css('ul.paging a.next/@href').text).empty?
    scrape_list(next_page)
  end
end

def scrape_person(url)
  noko = noko_for(url)
  data = { 
    image: noko.css('img.img-detail/@src').text
  }
end

scrape_list('http://dbqh.na.gov.vn/dbqh_p_0/ABC/all/type/0/Default.aspx')
archive_committees('http://dbqh.na.gov.vn/dbqh_p_0/ABC/all/type/0/Default.aspx')

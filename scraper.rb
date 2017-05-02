#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'

# require 'open-uri/cached'
# OpenURI::Cache.cache_path = '.cache'
require 'scraped_page_archive/open-uri'

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

class MemberPage < Scraped::HTML
  field :image do
    noko.css('img.img-detail/@src').text
  end

  field :source do
    url
  end
end

def scraper(h)
  url, klass = h.to_a.first
  klass.new(response: Scraped::Request.new(url: url).response)
end

def noko_for(url)
  Nokogiri::HTML(open(url).read)
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

def list_page_members(url)
  page = scraper(url => MembersPage)
  data = page.members.map do |person|
    person.merge(scraper(person[:source] => MemberPage).to_h)
  end
  return data if page.next_page.empty?
  (data + list_page_members(page.next_page)).flatten
end

url = 'http://dbqh.na.gov.vn/dbqh_p_0/ABC/all/type/0/Default.aspx'
data = list_page_members(url)
data.each { |mem| puts mem.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h } if ENV['MORPH_DEBUG']

ScraperWiki.sqliteexecute('DROP TABLE data') rescue nil
ScraperWiki.save_sqlite(%i[id term], data)

archive_committees('http://dbqh.na.gov.vn/dbqh_p_0/ABC/all/type/0/Default.aspx')

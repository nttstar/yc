require 'test/unit'
require 'nokogiri'
require 'mechanize'
require_relative '../../app/helpers/product_helper'

class XpathTest < Test::Unit::TestCase

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    # Do nothing
  end

  # Called after every test method runs. Can be used to tear
  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
    # Do nothing
  end


  # def test_xpath
  #   url = 'http://search.jd.com/Search?keyword=iphone5s'
  #   uri = URI(url)
  #   req = Net::HTTP::Get.new(uri)
  #   req.add_field('User-Agent', 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2227.0 Safari/537.36')
  #   res = Net::HTTP.start(uri.host, uri.port) {|http| http.request(req) }
  #   html = res.body
  #   STDERR.puts uri
  #   STDERR.puts html
  #   doc = Nokogiri::HTML(html)
  #   #r = doc.xpath '//*[contains(@id,"result_")]/div/div[2]/div[1]/a/h2'
  #   r = doc.xpath '//*[@id="result_0"]'
  #   STDERR.puts r.size
  #   r.each do |ir|
  #     STDERR.puts ir.content
  #   end
  # end
  def test_yhd
    url = 'http://search.yhd.com/s2/c0-0/kiphone5s'
    agent = Mechanize.new
    page = agent.get(url)
    html = page.body
    STDERR.puts html

    STDERR.puts html
    doc = Nokogiri::HTML(html)
    #r = doc.xpath '//*[contains(@id,"result_")]/div/div[2]/div[1]/a/h2'
    r = doc.xpath '//*[starts-with(@id,"pdlink2_")]'
    STDERR.puts r.size
    r.each do |ir|
      STDERR.puts ir.content.strip
    end
  end
end
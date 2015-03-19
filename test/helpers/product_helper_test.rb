require 'test/unit'
require_relative '../../app/helpers/product_helper'

class ProductTest < Test::Unit::TestCase

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    # Do nothing
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
    # Do nothing
  end

  # def test_spec
  #   query = "iphone5s"
  #   rule_id = :amazon
  #   rule = nil
  #   ProductHelper::RULES.each do |erule|
  #     if erule[:id] == rule_id
  #       rule = erule
  #       break
  #     end
  #   end
  #   html = ProductHelper::ProductFetcher.fetch(rule, query)
  #   #STDOUT.puts html
  #
  #
  #   products = ProductHelper::ProductParser.parse(rule,html)
  #   products.each do |product|
  #     STDERR.puts product
  #   end
  # end

  def test_all
    query = "iphone5s"

    products = ProductHelper.crawl(query)
    products.each do |product|
      #STDERR.puts product
    end
    pgroups = ProductHelper.clustering(products)
    pgroups.each do |pgroup|
      info = ""
      unless pgroup.spu.nil?
        info = pgroup.spu['Title']
      end
      STDERR.puts "#{pgroup.size},#{info}"
    end
  end
end
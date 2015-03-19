require 'net/http'
require 'uri'
require 'mechanize'
require 'logger'
require 'digest/md5'
require 'msgpack'
require 'msgpack/rpc'
require 'json'
module ProductHelper

  class ProductGroup
    attr_reader :size, :source_size, :price_range, :products, :spu
    def initialize(products_in_group, spu=nil)
      @size = 0
      @source_map = Hash.new(0)
      @price_range = [nil, nil]
      @source_size = @source_map.size
      @spu = spu
      @products = []
      unless products_in_group.nil?
        if products_in_group.is_a? Array
          products_in_group.each do |product|
            append(product)
          end
        else
          append(products_in_group)
        end
      end
    end

    def <<(product)
      append(product)
    end

    def append(product)
      @products << product
      @size = @products.size
      price = product[:Price]
      if price.is_a? Float
        if @price_range[0].nil? or price<@price_range[0]
          @price_range[0] = price
        end
        if @price_range[1].nil? or price>@price_range[1]
          @price_range[1] = price
        end
      end
      @source_map[product[:source_name]] += 1
      @source_size = @source_map.size
    end

    def pop
      return 0.0 if @spu.nil?
      return @products.inject(0.0) {|sum,p| sum + p[:pop]}
    end

    def sort!
      if !@spu.nil?
        @products.sort! do |x,y|
          xprice = x[:Price]
          yprice = y[:Price]
          if xprice.is_a? String
            -1
          elsif yprice.is_a? String
            1
          else
            xprice <=> yprice
          end
        end
      else
        @products.sort! {|x,y| y[:pop]<=>x[:pop]}
      end
    end
  end

  class YHttp
    def initialize
      @agent = Mechanize.new
      @agent.user_agent_alias = 'Windows Mozilla'
    end
    def get(url)
      begin
        uri = URI(url)
        page = @agent.get(uri)
        return page.body
      rescue
        return nil
      end
    end
  end

  @@yhttp = YHttp.new

  def self.get_http
    return @@yhttp
  end

  def self.wget(url)
    get_http.get(url)
  end

  PROPERTIES = [:Title, :Price, :Url, :Picture]

  ITEMS_PER_SITE = 20

  #jd, amazon, yhd, gnome, suning, 51buy, dangdang

  def self.suning(content)
    goods_content_start = content.index('"goods"')
    return [] if goods_content_start.nil?
    goods_content_start+=8
    goods_content_end = content.index('"goodsCount"',goods_content_start)
    return [] if goods_content_end.nil?
    goods_content_end-=1
    goods_content = content[goods_content_start...goods_content_end]
    goods = JSON.parse(goods_content)
    products = []
    goods.each do |good|
      p = {}
      p[:Title] = good['catentdesc']
      p[:Price] = good['price']
      id = good['partnumber']
      p[:Picture] = "http://image4.suning.cn/b2c/catentries/000000000#{id}_1_160x160.jpg"
      p[:Url] = "http://product.suning.com/#{id}.html"
      products << p
    end
    return products
  end

  RULES = [
      {
          :id => :jd, :name => '京东', :site_pop => 1.1,
          :url_spec => 'http://search.jd.com/search?keyword=%s&enc=utf-8&qrst=UNEXPAND&rt=1&wtype=1#filter',
          :property => {
              :Title => '//*[@id="plist"]/ul/li/div/div[2]/a',
              :Price => '//*[@id="plist"]/ul/li/div/div[3]/strong/@data-price',
              :Url => '//*[@id="plist"]/ul/li/div/div[2]/a/@href',
              :Picture => '//*[@id="plist"]/ul/li/div/div[1]/a/img/@data-lazyload'
          }
      },

      {
          :id => :amazon, :name => '亚马逊', :site_pop => 1.03,
          :url_spec => 'http://www.amazon.cn/s/ref=sr_nr_p_n_fulfilled_by_ama_0?rh=i%%3Aaps%%2Ck%%3A%s%%2Cp_n_fulfilled_by_amazon%%3A326314071',
          :property => {
              :Title => '//*[contains(@id,"result_")]/div/div[2]/div[1]/a/h2',
              #:Price => '//*[contains(@id,"result_")]/div/div[3]/div[1]/a/span',
              :Price => '//*[contains(@id,"result_")]//*[contains(@class, "a-color-price s-price")]',
              :Url => '//*[contains(@id,"result_")]/div/div[2]/div[1]/a/@href',
              :Picture => '//*[contains(@id,"result_")]/div/div[1]/div/div/a/img/@src'
          }
      },
      {
          :id => :yhd, :name => '一号店', :site_pop => 1.0,
          :url_spec => 'http://search.yhd.com/c0-0-0/b/a-s1-v0-p1-price-d0-f06-m1-rt0-pid-mid0-k%s',
          :property => {
              :Title => '//*[starts-with(@id,"pdlink2_")]/@title',
              :Price => '//*[starts-with(@id,"price0_")]/@yhdprice',
              :Url => '//*[starts-with(@id,"pdlink2_")]/@href',
              :Picture => '//*[starts-with(@id,"pdlink1_")]/img/@src|//*[starts-with(@id,"pdlink1_")]/img/@original'
          }
      },
      {
          :id => :gome, :name => '国美', :site_pop => 1.07,
          :url_spec => 'http://www.gome.com.cn/search?question=%s',
          :property => {
              :Title => '//*[@id="prodByAjax"]/ul/li/p[2]/a/@title',
              :Price => '//*[@id="prodByAjax"]/ul/li/p[3]/span[1]',
              :Url => '//*[@id="prodByAjax"]/ul/li/p[2]/a/@href',
              :Picture => '//*[@id="prodByAjax"]/ul/li/p[1]/a/img/@gome-src'
          }
      },
      {
          :id => :suning, :name => '苏宁', :site_pop => 1.04,
          #:url_spec => 'http://search.suning.com/%s/',
          :url_spec => 'http://search.suning.com/emall/mobile/mobileSearch.jsonp?keyword=%s&channel=&terminal=&cp=0&ps=20&st=0&set=5&cf=&iv=-1&ci=&ct=1&yuyue=-1&n=&channelId=WAP&callback=jQuery1720945795367937535_1426079448919&_=1426079449045',
          :property => method(:suning)
          # :property => {
          #     :Title => '//*[@id="proShow"]/ul/li/div/h3/a/p',
          #     :Price => '//*[@id="proShow"]/ul/li/div/div[1]/p/img/@src2',
          #     :Url => '//*[@id="proShow"]/ul/li/div/h3/a/@href',
          #     :Picture => '//*[@id="proShow"]/ul/li/a/img/@src|//*[@id="proShow"]/ul/li/a/img/@src2'
          # }
      },
      {
          :id => :yixun, :name => '易迅', :site_pop => 1.0,
          :url_spec => 'http://searchex.yixun.com/html?area=1&charset=utf-8&as=1&key=%s',
          :property => {
              :Title => '//*[@id="itemList"]/li/div/div[2]/p[2]/a/@title',
              :Price => '//*[@id="itemList"]/li/div/div[2]/p[3]/span[1]/span',
              :Url => '//*[@id="itemList"]/li/div/div[2]/p[2]/a/@href',
              :Picture => '//*[@id="itemList"]/li/div/div[1]/a/img/@init_src'
          }
      },
  ]

  class ProductFetcher
    def self.fetch(rule, query)
      eq = URI::encode(query)
      url = rule[:url_spec] % [eq]
      STDERR.puts url
      return ProductHelper.wget(url)
    end
  end

  class ProductParser

    def self.parse(rule, html)
      products = []
      if rule[:property].is_a? Method
        products = rule[:property].call(html)
      else
        doc = Nokogiri::HTML(html)
        rule[:property].each_pair do |k, v|
          xv = doc.xpath(v)
          pv = []
          xv.each do |ixv|
            sv = ixv.content.strip
            pv << sv
          end
          pv = pv[0..ITEMS_PER_SITE] if pv.size>ITEMS_PER_SITE
          STDERR.puts "ppp #{k} #{pv.size}"
          if products.empty?
            pv.size.times { products << {} }
          end
          products.each_with_index do |p,i|
            p[k] = pv[i]
          end
        end
      end
      rule_id = rule[:id]
      STDERR.puts "#{rule_id} pcount: #{products.size}"
      return [] if products.empty?
      #return []


      products.each_with_index do |p,i|
        rank = i
        pop = rule[:site_pop]/Math.log(rank+2.0)
        p.merge!({:source_id => rule_id, :source_name => rule[:name], :pop => pop})
        ProductHelper::PROPERTIES.each do |pname|
          pvalue = p[pname]
          fname = "general_#{pname}".to_sym
          if ProductParser.respond_to?(fname)
            pvalue = ProductParser.send(fname, pvalue)
          end
          fname = "#{rule_id}_#{pname}".to_sym
          if ProductParser.respond_to?(fname)
            pvalue = ProductParser.send(fname, pvalue)
          end
          unless pvalue.nil?
            p[pname] = pvalue
          end
        end

        url = p[:Url]
        next if url.nil?
        docid = Digest::MD5.hexdigest(url)
        p[:DOCID] = docid
      end
      return products
    end

    def self.general_Title(pvalue)
      return nil if pvalue.nil?
      return pvalue
    end

    def self.general_Price(pvalue)
      return nil if pvalue.nil?
      return pvalue if pvalue.is_a? Float
      return pvalue if pvalue.start_with?('http')
      STDERR.puts "before #{pvalue}"
      pvalue.gsub!('¥', '')
      pvalue.gsub!('￥', '')
      pvalue.gsub!(',', '')
      STDERR.puts "after #{pvalue}"

      return pvalue.to_f
    end


  end



  class ProductCrawler
    attr_reader :url_spec
    def initialize
    end

    def get_products(query)

      products = []
      threads = []
      ProductHelper::RULES.each do |rule|
        t = Thread.new do
          html = ProductFetcher.fetch(rule, query)
          next if html.nil?
          ps = ProductParser.parse(rule, html)
          products.concat(ps)
        end
        threads << t
      end
      threads.each do |t|
        t.join
      end
      return products
    end
    def get_body(query)
      url = @url_spec % [query]
      url = URI::encode(url)
      body = ProductHelper.wget(url)
      return body
    end

  end

  @@crawler = ProductCrawler.new

  def self.crawl(query)

    return @@crawler.get_products(query)

  end


  #SPU defined as [:docid, :url, :picture, :price(range), :title, :attribute]
  def self.get_spu(product)
    c = MessagePack::RPC::Client.new(Rails.configuration.matcher_ip, Rails.configuration.matcher_port)
    spu = nil
    begin
      price = product[:price]
      price = 0.0 if price.is_a? String
      spu = c.call(:match, product[:title], price)
    rescue
      STDERR.puts "get spu err"
      spu = nil
    end
    return spu
  end


  def self.do_matcher(mquery)
    #c = MessagePack::RPC::Client.new(Rails.configuration.matcher_ip, Rails.configuration.matcher_port)
    c = MessagePack::RPC::Client.new("192.168.1.199", 18299)
    c.timeout=600
    begin
      qt = mquery.to_json
      STDERR.puts "call matcher with ,len:#{mquery.size}"
      result = c.call(:match_all, qt)
      return JSON.parse(result[0])
    rescue
      STDERR.puts "matcher call err"
      return nil
    end
  end

  def self.clustering(products)
    mquery = []
    products.each do |product|
      mp = {:DOCID => product[:DOCID], :Title => product[:Title]}
      if product[:Price].is_a? Float
        mp[:Price] = product[:Price]
      end
      mquery << mp
    end
    mresult = do_matcher(mquery)
    rdocs = {}
    rspus = {}
    unless mresult.nil?
      rdocs = mresult['docs']
      rspus = mresult['spus']
    end
    pgroups = []
    pindex = {}
    products.each do |product|
      docid = product[:DOCID]
      uuid = rdocs[docid]
      uuid = '0' if uuid.nil?
      ind = pindex[uuid]
      if ind.nil?
        ind = pgroups.size
        pindex[uuid] = ind
        spu = rspus[uuid]
        pgroups << ProductGroup.new(product, spu)
      else
        pgroups[ind] << product
      end
    end
    pgroups.each do |pg|
      pg.sort!
    end
    pgroups.sort! {|x,y| y.pop <=> x.pop}
    return pgroups
  end
end

class ProductController < ApplicationController
  def index
  end

  def search
    @query = params[:q]
    unless @query.nil?
      products = ProductHelper.crawl(@query)
      @pgroups = ProductHelper.clustering(products)
    end
  end
end

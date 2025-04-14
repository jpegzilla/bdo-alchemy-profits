# frozen_string_literal: true

require 'httparty'
require 'json'

require_relative '../../utils/cli_utils/constants'
require_relative '../../utils/hash_cache'
require_relative '../../utils/npc_item_index'

CONSUMABLE_CATEGORY = 35
CONSUMABLE_SUBCATEGORIES = {
  offensive: 1,
  defensive: 2,
  functional: 3,
  potion: 5,
  other: 8,
  all: [1, 2, 3, 5, 8]
}.freeze

# get information used for searching specific categories
def category_search_options(url, search_url) # rubocop:disable Metrics/AbcSize
  # TODO: there's probably a smart / concise way to construct this array
  [
    {
      name: 'black stone',
      url: url,
      query_string: "#{ENVData::RVT}&mainCategory=30&subCategory=1",
      # update: ->(data) { { blackStoneResponse: data['list'] } },
      update: ->(data) { data['list'] }
    },
    {
      name: 'blood',
      url: search_url,
      query_string: "#{ENVData::RVT}&searchText='s+blood",
      # update: ->(data) { { bloodResponse: data['list'] } },
      update: ->(data) { data['list'] }
    },
    {
      name: 'reagent',
      url: search_url,
      query_string: "#{ENVData::RVT}&searchText=reagent",
      # update: ->(data) { { reagentResponse: data['list'] } },
      update: ->(data) { data['list'] }
    },
    {
      name: 'oil',
      url: search_url,
      query_string: "#{ENVData::RVT}&searchText=oil+of",
      # update: ->(data) { { oilResponse: data['list'] } },
      update: ->(data) { data['list'] }
    },
    {
      name: 'alchemy stone',
      url: search_url,
      query_string: "#{ENVData::RVT}&searchText=stone+of",
      # update: ->(data) { { alchemyStoneResponse: data['list'] } },
      update: ->(data) { data['list'] }
    },
    {
      name: 'magic crystal',
      url: search_url,
      query_string: "#{ENVData::RVT}&searchText=magic+crystal",
      # update: ->(data) { { magicCrystalResponse: data['list'] } },
      update: ->(data) { data['list'] }
    },
    {
      name: 'offensive',
      url: url,
      query_string:
        "#{ENVData::RVT}&mainCategory=#{CONSUMABLE_CATEGORY}&subCategory=#{CONSUMABLE_SUBCATEGORIES[:offensive]}",
      # update: ->(data) { { offensiveResponse: data['marketList'] } },
      update: ->(data) { data['marketList'] }
    },
    {
      name: 'defensive',
      url: url,
      query_string:
        "#{ENVData::RVT}&mainCategory=#{CONSUMABLE_CATEGORY}&subCategory=#{CONSUMABLE_SUBCATEGORIES[:defensive]}",
      # update: ->(data) { { defensiveResponse: data['marketList'] } },
      update: ->(data) { data['marketList'] }
    },
    {
      name: 'functional',
      url: url,
      query_string:
            "#{ENVData::RVT}&mainCategory=#{CONSUMABLE_CATEGORY}&subCategory=#{CONSUMABLE_SUBCATEGORIES[:functional]}",
      # update: ->(data) { { functionalResponse: data['marketList'] } },
      update: ->(data) { data['marketList'] }
    },
    {
      name: 'potion',
      url: url,
      query_string:
        "#{ENVData::RVT}&mainCategory=#{CONSUMABLE_CATEGORY}&subCategory=#{CONSUMABLE_SUBCATEGORIES[:potion]}",
      # update: ->(data) { { potionResponse: data['marketList'] } },
      update: ->(data) { data['marketList'] }
    },
    {
      name: 'other',
      url: url,
      query_string:
        "#{ENVData::RVT}&mainCategory=#{CONSUMABLE_CATEGORY}&subCategory=#{CONSUMABLE_SUBCATEGORIES[:other]}",
      # update: ->(data) { { otherResponse: data['marketList'] } },
      update: ->(data) { data['marketList'] }
    }
  ]
end

# search for information on recipes in given categories
class MarketSearcher
  def initialize(region, cli)
    @root_url = ENVData.get_root_url region
    @market_list_url = "#{@root_url}#{ENVData::WORLD_MARKET_LIST}"
    @market_search_url = "#{@root_url}#{ENVData::MARKET_SEARCH_LIST}"
    @market_sub_url = "#{@root_url}#{ENVData::MARKET_SUB_LIST}"
    @market_sell_buy_url = "#{@root_url}#{ENVData::MARKET_SELL_BUY_INFO}"
    @market_cache = HashCache.new ENVData::MARKET_CACHE
    @bdo_codex_cache = HashCache.new ENVData::BDO_CODEX_CACHE
    @cli = cli
    @ingredient_cache = {}
    @out_of_stock_items = []
  end

  def get_alchemy_market_data(category)
    category_data = {}
    data = construct_item_data(category, category == 'all')

    category_data[category] = data
    @market_cache.write category_data

    data
  end

  def get_price_data(elem)
    data = HTTParty.post(
      URI(@market_sub_url),
      headers: ENVData::REQUEST_OPTS[:central_market_headers],
      body: "#{ENVData::RVT}&mainKey=#{elem['mainKey']}&usingCleint=0",
      content_type: 'application/x-www-form-urlencoded'
    )['detailList'][0]

    { **elem, **data }
  end

  def construct_item_data(subcategory, all_subcategories)
    aggregate = aggregate_category_data(@market_list_url, @market_search_url, subcategory, all_subcategories)

    filtered_aggregate = aggregate.filter do |elem|
      elem != nil
    end

    # TODO: this is probably not a smart way to do this type of retry logic
    cache = @market_cache.read subcategory
    mapped_aggregate = filtered_aggregate.map do |elem|
      cached_item = cache&.dig(elem['mainKey'])

      return cached_item unless cached_item.nil?

      begin
        get_price_data elem
      rescue
        sleep 10
        begin
          get_price_data elem
        rescue
          nil
        end
      end
    end.filter { |item| !item&.nil? && !item&.dig('pricePerOne').nil? }

    mapped_aggregate.sort do |a, b|
      b['pricePerOne'] - a['pricePerOne']
    end
  end

  def aggregate_category_data(url, search_url, subcategory, all_subcategories)
    make_match_options = proc do |subcat_to_match|
      {
        subcat_to_match: subcat_to_match,
        subcategory: subcategory,
        all_subcategories: all_subcategories
      }
    end

    # aggregate_response = {}
    aggregate_response = []

    category_search_options(url, search_url).each do |category_opts|
      do_if_category_matches(make_match_options.call(category_opts[:name])) do
        begin
          data = HTTParty.post(
            URI(category_opts[:url]),
            headers: ENVData::REQUEST_OPTS[:central_market_headers],
            body: category_opts[:query_string],
            content_type: 'application/x-www-form-urlencoded'
          )

          # aggregate_response = { **aggregate_response, **category_opts[:update].call(data) } if data
          aggregate_response.push category_opts[:update].call(data) if data
        rescue
          []
        end
      end
    end

    aggregate_response.flatten
  end

  def get_item_price_info(ingredient_id, is_recipe_ingredient)
    npc_item = NPCItemIndex.get_item(ingredient_id)

    return npc_item if npc_item

    if is_recipe_ingredient
      ingredient_data = HTTParty.post(
        URI(@market_sub_url),
        headers: ENVData::REQUEST_OPTS[:central_market_headers],
        body: "#{ENVData::RVT}&mainKey=#{ingredient_id}&usingCleint=0",
        content_type: 'application/x-www-form-urlencoded'
      )['detailList'][0]

      body_string = "#{ENVData::RVT}&mainKey=#{ingredient_data['mainKey']}&subKey=0&chooseKey=0&isUp=true&keyType=0&name=#{URI.encode_www_form_component(ingredient_data['name'])}"

      detailed_price_list = HTTParty.post(
        URI(@market_sell_buy_url),
        headers: ENVData::REQUEST_OPTS[:central_market_headers],
        body: body_string,
        content_type: 'application/x-www-form-urlencoded'
      )

      optimal_price = detailed_price_list['marketConditionList'].sort do |a, b|
        b['sellCount'] - a['sellCount']
      end[0]

      if optimal_price['pricePerOne'] && optimal_price['sellCount']
        return { **ingredient_data, count: optimal_price['sellCount'], pricePerOne: optimal_price['pricePerOne'] }
      else
        return { **ingredient_data,count: ingredient_data['count'], pricePerOne: ingredient_data['pricePerOne'] }
      end
    end
  end

  def get_all_recipe_prices(item_codex_data, subcategory)
    # TODO: remove this limiter thing
    item_codex_data[0..0].each do |item_with_recipe|
      potential_recipes = []
      name = item_with_recipe[:name].downcase
      recipe_list = item_with_recipe[:recipe_list]

      @cli.vipiko "I'll ask a merchant about the price of ingredients for #{@cli.yellow name}!"

      # TODO: remove this limiter thing
      recipe_list[0..0].each do |recipe|
        potential_recipe = []

        recipe.each do |ingredient|
          ingredient_id = ingredient['id']
          quant = ingredient['quant']

          if @ingredient_cache[ingredient_id]
            cached_ingredient = { **@ingredient_cache[ingredient_id], quant: quant }
            potential_recipe.push cached_ingredient
            next
          end

          item_price_info_hash = get_item_price_info ingredient_id, true

          next if item_price_info_hash.nil?

          item_price_info = item_price_info_hash.transform_keys { |key|
            key.to_s.gsub(/(.)([A-Z])/,'\1_\2').downcase.to_sym
          }

          if item_price_info[:count].zero? && rand > 0.5
            @out_of_stock_items.push(item_price_info[:name].downcase)
          end

          @ingredient_cache[ingredient_id] = item_price_info

          stock_count = get_stock_count item_price_info

          npc_data = {}
          npc_data = item_price_info if item_price_info[:is_npc_item]

          potential_recipe_hash = {
            name: item_price_info[:name],
            price: item_price_info[:price_per_one],
            id: item_price_info[:main_key],
            total_trade_count: item_price_info[:total_trade_count].to_i.zero? ? 'not available' : item_price_info[:total_trade_count],
            total_in_stock: stock_count.zero? ? 'not available' : stock_count,
            main_category: item_price_info[:main_category],
            sub_category: item_price_info[:sub_category],
            quant: quant,
            **npc_data
          }

          potential_recipe.push potential_recipe_hash
        end

        next unless potential_recipe.length == recipe.length

        potential_recipes.push potential_recipe
      end

      return potential_recipes
    end
  end

  def map_recipe_prices potential_recipes
    mapped_recipe_prices = []
    out_of_stock_items = []
  end

  def get_stock_count(item_info)
    return Float::INFINITY if item_info.dig(:is_npc_item)

    item_info[:total_in_stock].to_i.zero? ? item_info[:count].to_i : item_info[:total_in_stock].to_i
  end

  # async def do_if_category_matches(options, &procedure)
  #   procedure.call.wait if options[:subcategory] == options[:subcat_to_match] || options[:all_subcategories]
  # end

  def do_if_category_matches(options, &procedure)
    procedure.call if options[:subcategory] == options[:subcat_to_match] || options[:all_subcategories]
  end
end

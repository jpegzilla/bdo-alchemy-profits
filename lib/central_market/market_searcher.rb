# frozen_string_literal: true

require 'httparty'
require 'json'

require_relative '../../utils/cli_utils/constants'

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
  def initialize(region)
    @root_url = ENVData.get_root_url region
    @market_list_url = "#{@root_url}#{ENVData::WORLD_MARKET_LIST}"
    @market_search_url = "#{@root_url}#{ENVData::MARKET_SEARCH_LIST}"
    @market_sub_url = "#{@root_url}#{ENVData::MARKET_SUB_LIST}"
  end

  def get_market_item_cache
    file_content = File.read(ENVData::MARKET_CACHE)

    begin
      return JSON.parse file_content unless file_content.empty?

      {}
    rescue
      {}
    end
  end

  def get_alchemy_market_data(category)
    data = construct_item_data(category, category == 'all')

    # cache data
    item_map = get_market_item_cache
    File.open(ENVData::MARKET_CACHE, 'w') do |file|
      data.map do |item|
        item_map[item['mainKey']] = item
      end

      file.write item_map.to_json
    end

    data
  end

  def get_price_data(elem)
    data = HTTParty.post(
      URI(@market_sub_url),
      headers: ENVData::REQUEST_OPTS[:headers],
      body: "#{ENVData::RVT}&mainKey=#{elem['mainKey']}&usingCleint=0",
      content_type: 'application/x-www-form-urlencoded'
    )['detailList'][0]

    { **elem, **data }
  end

  def construct_item_data(subcategory, all_subcategories)
    aggregate = aggregate_category_data(@market_list_url, @market_search_url, subcategory, all_subcategories)

    filtered_aggregate = aggregate.filter do |elem|
      !elem&.nil?
    end

    # TODO: this is probably not a smart way to do this type of retry logic
    cache = get_market_item_cache
    mapped_aggregate = filtered_aggregate.map do |elem|
      cached_item = cache[elem['mainKey']]

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
            headers: ENVData::REQUEST_OPTS[:headers],
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

  # async def do_if_category_matches(options, &procedure)
  #   procedure.call.wait if options[:subcategory] == options[:subcat_to_match] || options[:all_subcategories]
  # end

  def do_if_category_matches(options, &procedure)
    procedure.call if options[:subcategory] == options[:subcat_to_match] || options[:all_subcategories]
  end
end

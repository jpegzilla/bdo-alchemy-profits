# frozen_string_literal: true

require 'async/await'
require 'httparty'

require_relative '../cli_utils/constants'

# get information used for searching specific categories
def category_search_options(url, search_url)
  [
    {
      name: 'black stone',
      url: url,
      query_string: "#{ENVData::RVT}&mainCategory=30&subcategory=1",
      update: ->(data) { { blackStoneResponse: data } },
      search: false,
    },
    {
      name: 'blood',
      url: search_url,
      query_string: "#{ENVData::RVT}&searchText='s+blood",
      update: ->(data) { { bloodResponse: data } },
      search: true
    },
    {
      name: 'reagent',
      url: search_url,
      query_string: "#{ENVData::RVT}&searchText=reagent",
      update: ->(data) { { reagentResponse: data } },
      search: true
    },
    {
      name: 'oil',
      url: search_url,
      query_string: "#{ENVData::RVT}&searchText=oil+of",
      update: ->(data) { { oilResponse: data } },
      search: true
    },
    {
      name: 'alchemy stone',
      url: search_url,
      query_string: "#{ENVData::RVT}&searchText=stone+of",
      update: ->(data) { { alchemyStoneResponse: data } },
      search: true
    },
    {
      name: 'magic crystal',
      url: search_url,
      query_string: "#{ENVData::RVT}&searchText=magic+crystal",
      update: ->(data) { { magicCrystalResponse: data } },
      search: true
    }
  ]
end

# search for information on recipes in given categories
class MarketSearcher
  def initialize(region)
    @consumable_category = 35
    @consumable_subcategories = {
      offensive: 1,
      defensive: 2,
      functional: 3,
      potion: 5,
      other: 8,
      all: [1, 2, 3, 5, 8]
    }

    @root_url = ENVData.get_root_url region
    @market_list_url = "#{@root_url}#{ENVData::WORLD_MARKET_LIST}"
    @market_search_url = "#{@root_url}#{ENVData::MARKET_SEARCH_LIST}"
  end

  def get_alchemy_market_data(subcategory)
    construct_item_data(subcategory, subcategory == 'all')
  end

  def construct_item_data(subcategory, all_subcategories)
    responses = aggregate_category_data(@market_list_url, @market_search_url, subcategory, all_subcategories)

    pp responses
  end

  def aggregate_category_data(url, search_url, subcategory, all_subcategories)
    make_match_options = proc do |subcat_to_match|
      {
        subcat_to_match: subcat_to_match,
        subcategory: subcategory,
        all_subcategories: all_subcategories
      }
    end

    aggregate_response = {}

    category_search_options(url, search_url).each do |category_opts|
      do_if_category_matches(make_match_options.call(category_opts[:name])) do
        # data = Internet.post(
        #   category_opts[:url],
        #   ENVData::REQUEST_OPTS[:headers],
        #   category_opts[:query_string]
        # )

        pp 'uri:', URI(category_opts[:url])
        puts
        pp 'headers', ENVData::REQUEST_OPTS[:headers]
        puts
        pp 'query', category_opts[:query_string]
        puts

        data = HTTParty.post(
          URI(category_opts[:url]),
          headers: ENVData::REQUEST_OPTS[:headers],
          body: URI(category_opts[:query_string]).to_s
        )

        pp data

        # if data
        #   aggregate_response = { **aggregate_response, **category_opts[:update].call(data) }
        # end
      end
    end

    aggregate_response
  end

  # async def do_if_category_matches(options, &procedure)
  #   procedure.call.wait if options[:subcategory] == options[:subcat_to_match] || options[:all_subcategories]
  # end

  def do_if_category_matches(options, &procedure)
    procedure.call if options[:subcategory] == options[:subcat_to_match] || options[:all_subcategories]
  end
end

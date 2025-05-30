# frozen_string_literal: true

require_relative '../utils/constants'

module MarketSearchTools
  include Utils

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
        update: ->(data) { data['marketList'] }
      },
      {
        name: 'misc',
        url: url,
        query_string: "#{ENVData::RVT}&mainCategory=25&subCategory=8",
        update: ->(data) { data['marketList'] }
      },
      {
        name: 'other tools',
        url: url,
        query_string: "#{ENVData::RVT}&mainCategory=40&subCategory=10",
        update: ->(data) { data['marketList'] }
      },
      {
        name: 'blood',
        url: search_url,
        query_string: "#{ENVData::RVT}&searchText='s+blood",
        update: ->(data) { data['list'] }
      },
      {
        name: 'essences of dawn',
        url: search_url,
        query_string: "#{ENVData::RVT}&searchText=essence+of+dawn",
        update: ->(data) { data['list'] }
      },
      {
        name: 'reagent',
        url: search_url,
        query_string: "#{ENVData::RVT}&searchText=reagent",
        update: ->(data) { data['list'] }
      },
      {
        name: 'oil',
        url: search_url,
        query_string: "#{ENVData::RVT}&searchText=oil+of",
        update: ->(data) { data['list'] }
      },
      {
        name: 'alchemy stone',
        url: search_url,
        query_string: "#{ENVData::RVT}&searchText=imperfect+alchemy+stone+of",
        update: ->(data) { data['list'].filter { |i| i['grade'] == 0 } }
      },
      # {
      #   name: 'magic crystal',
      #   url: search_url,
      #   query_string: "#{ENVData::RVT}&searchText=magic+crystal",
      #   # update: ->(data) { { magicCrystalResponse: data['list'] } },
      #   update: ->(data) { data['list'] }
      # },
      {
        name: 'combined crystals',
        url: url,
        query_string: "#{ENVData::RVT}&mainCategory=50&subCategory=4",
        update: ->(data) { data['marketList'] }
      },
      {
        name: 'offensive',
        url: url,
        query_string:
          "#{ENVData::RVT}&mainCategory=#{CONSUMABLE_CATEGORY}&subCategory=#{CONSUMABLE_SUBCATEGORIES[:offensive]}",
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
      },
      {
        name: 'manos',
        url: search_url,
        query_string: "#{ENVData::RVT}&searchText=manos",
        # update: ->(data) { { otherResponse: data['marketList'] } },
        update: ->(data) { data['list'] }
      },
      {
        name: 'purified lightstone',
        url: search_url,
        query_string: "#{ENVData::RVT}&searchText=purified+lightstone+of",
        # update: ->(data) { { otherResponse: data['marketList'] } },
        update: ->(data) { data['list'] }
      }
    ]
  end
end

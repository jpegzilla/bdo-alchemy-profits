# frozen_string_literal: true

require 'httparty'
require 'json'

require_relative '../../utils/cli_utils/constants'
require_relative '../../utils/hash_cache'
require_relative '../../utils/npc_item_index'
require_relative '../../utils/price_calculator'

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
      update: ->(data) { data['list'].filter { |i| i['grade'] == 0 } }
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
    @region_subdomain = CLIConstants::REGION_DOMAINS[region.to_sym].split('.')[1..].join('.')
    @market_list_url = "#{@root_url}#{ENVData::WORLD_MARKET_LIST}"
    @market_search_url = "#{@root_url}#{ENVData::MARKET_SEARCH_LIST}"
    @market_sub_url = "#{@root_url}#{ENVData::MARKET_SUB_LIST}"
    @market_sell_buy_url = "#{@root_url}#{ENVData::MARKET_SELL_BUY_INFO}"
    # @market_cache = HashCache.new ENVData::MARKET_CACHE
    @bdo_codex_cache = HashCache.new ENVData::BDO_CODEX_CACHE
    @cli = cli
    @ingredient_cache = {}
    @out_of_stock_items = []
  end

  def get_alchemy_market_data(category)
    construct_item_data(category, category == 'all')
  end

  def get_price_data(elem)
    data = HTTParty.post(
      URI(@market_sub_url),
      headers: ENVData.get_central_market_headers(ENVData.get_incap_cookie(@region_subdomain)),
      body: "#{ENVData::RVT}&mainKey=#{elem['mainKey']}&usingCleint=0",
      content_type: 'application/x-www-form-urlencoded'
    )

    sleep 1

    if data&.dig('detailList')
      # data_to_use = { **elem, **data['detailList'][0] }
      # cache_data = {}
      # cache_data[elem['mainKey']] = data_to_use
      # @market_cache.write cache_data
      { **elem, **data['detailList'][0] }
    else
      puts 'incapsula might have your number, ip swap'
    end
  end

  def construct_item_data(subcategory, all_subcategories)
    aggregate = aggregate_category_data(@market_list_url, @market_search_url, subcategory, all_subcategories)

    filtered_aggregate = aggregate.filter do |elem|
      elem != nil
    end

    # TODO: this is probably not a smart way to do this type of retry logic
    puts
    mapped_aggregate = filtered_aggregate.map.with_index do |elem, index|
      # cached_item = @market_cache.read elem['mainKey']

      @cli.vipiko_overwrite "(#{index + 1} / #{filtered_aggregate.length})  researching #{@cli.yellow elem['name'].downcase}... (category: #{subcategory})"

      # return cached_item unless cached_item.nil?

      begin
        get_price_data elem
      rescue
        sleep 10
        begin
          get_price_data elem
        rescue StandardError => error
          puts @cli.red("this could be a network failure. construct_item_data broke.")

          File.open(ENVData::ERROR_LOG, 'a+') do |file|
            file.write(error.full_message)
            file.write("\n\r")
          end

          []
        end
      end
    end.filter { |item| !item&.nil? && !item&.dig('pricePerOne').nil? }

    puts
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

          sleep 1

          # aggregate_response = { **aggregate_response, **category_opts[:update].call(data) } if data
          aggregate_response.push category_opts[:update].call(data) if data
        rescue StandardError => error
          puts @cli.red("this could be a network failure. aggregate_category_data broke.")

          File.open(ENVData::ERROR_LOG, 'a+') do |file|
            file.write(error.full_message)
            file.write("\n\r")
          end

          []
        end
      end
    end

    aggregate_response.flatten
  end

  def get_item_price_info(ingredient_id, is_recipe_ingredient = true)
    npc_item = NPCItemIndex.get_item(ingredient_id)

    return npc_item if npc_item

    if is_recipe_ingredient
      ingredient_data = {}

      begin
        ingredient_data = HTTParty.post(
          URI(@market_sub_url),
          headers: ENVData.get_central_market_headers(ENVData.get_incap_cookie(@region_subdomain)),
          body: "#{ENVData::RVT}&mainKey=#{ingredient_id}&usingCleint=0",
          content_type: 'application/x-www-form-urlencoded'
        )

        sleep rand(1..3)
      rescue StandardError => error
        puts @cli.red("this could be a network failure. get_item_price_info broke.")

        File.open(ENVData::ERROR_LOG, 'a+') do |file|
          file.write(error.full_message)
          file.write("\n\r")
        ingredient_data = {}
        end
      end

      ingredient_data = {} if ingredient_data.include? 'use a different browser'

      if ingredient_data.dig('detailList')
        resolved_data = ingredient_data['detailList'][0]
        unless resolved_data.nil?
          body_string = "#{ENVData::RVT}&mainKey=#{resolved_data['mainKey']}&subKey=0&chooseKey=0&isUp=true&keyType=0&name=#{URI.encode_www_form_component(resolved_data['name'])}"

          detailed_price_list = {}

          begin
            detailed_price_list = HTTParty.post(
              URI(@market_sell_buy_url),
              headers: ENVData.get_central_market_headers(ENVData.get_incap_cookie(@region_subdomain)),
              body: body_string,
              content_type: 'application/x-www-form-urlencoded'
            )
            sleep rand
          rescue StandardError => error
            puts @cli.red("this could be a network failure. get_item_price_info broke.")

            File.open(ENVData::ERROR_LOG, 'a+') do |file|
              file.write(error.full_message)
              file.write("\n\r")
              detailed_price_list = {}
            end
          end

          optimal_prices = detailed_price_list&.dig('marketConditionList')&.sort do |a, b|
            b['sellCount'] - a['sellCount']
          end

          total_stock = optimal_prices.to_a.map { |price| price["sellCount"] }.sum

          optimal_price = optimal_prices.to_a.first

          if optimal_price
            if optimal_price['pricePerOne'] && optimal_price['sellCount']
              { **resolved_data, count: total_stock, pricePerOne: optimal_price['pricePerOne'] }
            else
              { **resolved_data, count: total_stock, pricePerOne: resolved_data['pricePerOne'] }
            end
          end
        end
      end

    end
  end

  def get_all_recipe_prices(item_codex_data, subcategory)
    mapped_recipe_prices = []
    out_of_stock_items = []
    # vipiko is about to start writing carriage returns,
    # so printing newline here

    item_codex_data.each.with_index do |item_with_recipe, index|
      potential_recipes = []
      name = item_with_recipe[:name].downcase
      recipe_list = item_with_recipe[:recipe_list]

      @cli.vipiko_overwrite "(#{index + 1} / #{item_codex_data.length}) I'll ask a merchant about the price of ingredients for #{@cli.yellow name}!"

      recipe_list.each do |(recipe_id, recipe)|
        potential_recipe = []

        recipe.each do |ingredient|
          ingredient_id = ingredient['id'] ? ingredient['id'] : ingredient[:id]
          quant = ingredient['quant'] ? ingredient['quant'] : ingredient[:quant]

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

          stock_count = get_stock_count item_price_info

          # attach the npc item data (such as infinite stock, etc) to the item
          npc_data = {}
          npc_data = item_price_info if item_price_info[:is_npc_item]
          price_per_one = npc_data[:price].to_i.zero? ? item_price_info[:price_per_one].to_i : npc_data[:price].to_i

          # TODO: this is ridiculous, dedupe the hash values
          potential_ingredient_hash = {
            name: item_price_info[:name],
            price: price_per_one,
            id: item_price_info[:main_key],
            total_trade_count: item_price_info[:total_trade_count].to_i.zero? ? 'not available' : item_price_info[:total_trade_count],
            total_in_stock: stock_count,
            main_category: item_price_info[:main_category],
            sub_category: item_price_info[:sub_category],
            quant: quant,
            price_per_one: price_per_one,
            count: stock_count,
            for_recipe_id: recipe_id,
            **npc_data
          }

          @ingredient_cache[ingredient_id] = potential_ingredient_hash

          potential_recipe.push potential_ingredient_hash
        end

        next unless potential_recipe.length == recipe.length

        potential_recipes.push potential_recipe
      end

      mapped_recipe_prices.push map_recipe_prices(potential_recipes, item_with_recipe, subcategory)
    end

    @cli.vipiko_overwrite "done!"

    puts "\n\n"

    mapped_recipe_prices.filter { |e| !e.nil? && !!e }
  end

  def map_recipe_prices(potential_recipes, item, category)
    average_procs = 1

    if [25, 35].include? item[:main_category]
      unless /oil of|draught|\[mix\]|\[party\]|immortal:|perfume|indignation/im.match item[:name].downcase
        average_procs = 2.5
      end

      if category == 'reagent' || /reagent/.match(item[:name].downcase)
        average_procs = 3
      end
    end

    # if item[:name].to_s.downcase == 'clear liquid reagent'
    #   puts
    #   pp "ITEM"
    #   puts
    #   ap item
    #   puts
    #   pp "potential RECIPES"
    #   ap potential_recipes
    #   puts
    #   puts item[:name]
    #   puts
    #   print 'average_procs: ', average_procs
    #   puts
    #   puts
    # end

    filtered_recipes = potential_recipes.filter do |recipe|
      recipe.all? do |ingredient|
        if ingredient[:total_in_stock] == Float::INFINITY
          true
        else
          stock = ingredient[:total_in_stock].to_i.zero? ? ingredient[:count] : ingredient[:total_in_stock]

          stock == Float::INFINITY ? true : stock.to_i > 0
        end
      end
    end
    # if item[:name].to_s.downcase == 'clear liquid reagent'
    #   print 'filtered_recipes: ', filtered_recipes
    #   puts
    # end

    selected_recipe = filtered_recipes.sort_by do |recipe|
      recipe.map { |ingredient| mapper ingredient }.sum
    end[0]
    # if item[:name].to_s.downcase == 'clear liquid reagent'
    #   print 'selected_recipe: '
    #   puts
    #   ap selected_recipe
    # end

    return nil if selected_recipe.nil?

    # remove recipes where one ingredient is used twice
    # this usually happens because of incorrect substitution being
    # found from bdocodex. or maybe they're not incorrect, and there
    # are some seriously mysterious alchemy recipes out there...
    ingredients_already_appeared = []
    filtered_selected_recipe = selected_recipe.filter do |ingredient|
      return false if ingredients_already_appeared.include? ingredient[:name]
      ingredients_already_appeared.push(ingredient[:name])
      true
    end

    return nil if filtered_selected_recipe.length != selected_recipe.length

    total_ingredient_cost = (selected_recipe.map { |ing| ing[:price_per_one] }.sum / average_procs).floor
    total_ingredient_stock = selected_recipe.filter { |ing| !ing[:is_npc_item] }.map { |ing| ing[:total_in_stock] }.sum
    any_ingredient_out = selected_recipe.any? { |ing| ing[:total_in_stock].zero? || ing[:total_in_stock] < ing[:quant] }

    body_string = "#{ENVData::RVT}&mainKey=#{item[:id]}&subKey=0&chooseKey=0&isUp=true&keyType=0&name=#{URI.encode_www_form_component(item[:name])}"

    item_price_data = HTTParty.post(
      URI(@market_sell_buy_url),
      headers: ENVData::REQUEST_OPTS[:central_market_headers],
      body: body_string,
      content_type: 'application/x-www-form-urlencoded'
    )

    # if item[:name].to_s.downcase == 'clear liquid reagent'
    #   puts 'item price data: '
    #   puts
    #   ap item_price_data
    # end

    # assuming we were able to find the item price list
    if item_price_data&.dig('marketConditionList')
      item_market_sell_price = item_price_data['marketConditionList']&.last&.dig('pricePerOne').to_i
      raw_profit_with_procs = (item_market_sell_price - total_ingredient_cost) * average_procs
      raw_profit_before_procs = item_market_sell_price - total_ingredient_cost

      # if item[:name].to_s.downcase == 'clear liquid reagent'
      #   puts 'other information that could cause omission: '
      #   puts
      #   print 'raw_profit_before_procs: ', raw_profit_before_procs
      #   puts
      #   print 'item_market_sell_price: ', item_market_sell_price
      #   puts
      #   print 'total_ingredient_cost: ', total_ingredient_cost
      #   puts
      #   print 'total_ingredient_stock: ', total_ingredient_stock
      #   puts
      #   ap item_price_data
      # end

      # TODO: allow the user to configure if the tool should show them
      # out of stock / unprofitable recipes
      return nil if raw_profit_before_procs.zero?
      return nil if any_ingredient_out
      return nil if total_ingredient_stock < 10

      max_potion_count = selected_recipe.map { |ing| ing[:total_in_stock] == Float::INFINITY ? Float::INFINITY : (ing[:total_in_stock] / ing[:quant]).floor }.min

      # important - the total cost of making the maximum possible
      # amount of this recipe
      # @type [Integer]
      total_max_ingredient_cost = total_ingredient_cost * max_potion_count

      # important - the untaxed sell price of the maximum amount of this
      # recipe
      # @type [Integer]
      raw_max_market_sell_price = (max_potion_count * item_market_sell_price) * average_procs

      # taxed profit on selling one of this this recipe, with
      # average procs accounted for
      # @type [Integer]
      taxed_sell_profit_after_procs = (((PriceCalculator.calculate_taxed_price(item_market_sell_price) - total_ingredient_cost)) * average_procs).floor

      # taxed profit on selling max amount of this this recipe, with
      # average procs accounted for
      # @type [Integer]
      max_taxed_sell_profit_after_procs = (PriceCalculator.calculate_taxed_price(item_market_sell_price * max_potion_count) - total_max_ingredient_cost) * average_procs

      return if max_taxed_sell_profit_after_procs.to_i <= 0

      # if item[:name].to_s.downcase == 'clear liquid reagent'
      #   puts
      #   pp "ITEM"
      #   puts
      #   ap item
      #   puts
      #   pp "RECIPE"
      #   puts
      #   ap selected_recipe
      #   puts
      #   puts item[:name]
      #   print 'total_max_ingredient_cost: ', total_max_ingredient_cost
      #   puts
      #   print 'item_market_sell_price: ', item_market_sell_price
      #   puts
      #   print 'max_potion_count: ', max_potion_count
      #   puts
      #   print 'average_procs: ', average_procs
      #   puts
      #   print 'total_ingredient_cost: ', total_ingredient_cost
      #   puts
      #   puts
      # end

      stock_counts = []
      # TODO: holy fuck extract some of this
      # at least this entire loop
      # remember, @cli.vipiko has to say this for colors to work
      selected_recipe.each do |ingredient|
        amount_required_for_max_potions = max_potion_count * ingredient[:quant]
        ingredient_market_sell_price = ingredient[:price].to_i

        next if (amount_required_for_max_potions * ingredient_market_sell_price) < 0

        raw_max_ingredient_sell_price = ingredient[:price] * max_potion_count
        formatted_price = @cli.yellow PriceCalculator.format_price ingredient_market_sell_price
        formatted_max_price = @cli.yellow PriceCalculator.format_price raw_max_ingredient_sell_price
        formatted_potion_amount = @cli.yellow PriceCalculator.format_num ingredient[:quant]
        formatted_max_potion_amount = @cli.yellow PriceCalculator.format_num max_potion_count
        formatted_stock_count = @cli.yellow PriceCalculator.format_num ingredient[:total_in_stock]
        formatted_npc_information = ingredient[:is_npc_item] ? @cli.yellow(" (sold by #{ingredient[:npc_type]} npcs)") : ''

        stock_counts.push "#{formatted_potion_amount.ljust(4, ' ')} [max: #{formatted_max_potion_amount}] #{@cli.yellow "#{ingredient[:name].downcase}: #{formatted_stock_count}"} in stock#{formatted_npc_information}. price: #{formatted_price} [for max: #{formatted_max_price}]"
      end

      market_stock_string = item[:total_in_stock] > 5000 ? @cli.red(PriceCalculator.format_num(item[:total_in_stock])) : @cli.green(PriceCalculator.format_num(item[:total_in_stock]))

      trade_count_string = item[:total_trade_count] < 1000000 ? @cli.red(PriceCalculator.format_num(item[:total_trade_count])) : @cli.green(PriceCalculator.format_num(item[:total_trade_count]))

      calculated_time = max_potion_count * 1.2
      crafting_time_string = calculated_time > 21600 ? @cli.red((seconds_to_str(calculated_time))) : @cli.green((seconds_to_str(calculated_time)))

      information = "    #{@cli.yellow "[#{item[:id]}] [#{item[:name].downcase}], recipe id: #{selected_recipe[0][:for_recipe_id]}"}

    #{padstr("market price of item")}#{@cli.yellow PriceCalculator.format_price item_market_sell_price}
    #{padstr("market stock of item")}#{market_stock_string}
    #{padstr("total trades of item")}#{trade_count_string}
    #{padstr("max amount you can create")}#{@cli.yellow PriceCalculator.format_num max_potion_count}
    #{padstr("cost of ingredients")}#{@cli.yellow PriceCalculator.format_price total_ingredient_cost} (accounting for average #{average_procs} / craft)
    #{padstr("max cost of ingredients")}#{@cli.yellow PriceCalculator.format_price total_max_ingredient_cost} (accounting for average #{average_procs} / craft)
    #{padstr("time to craft max")}#{crafting_time_string} (accounting for average 1.2s / craft - typical server delay)

\t#{stock_counts.join "\n\t"}

    total income for max items before cost subtraction #{@cli.green PriceCalculator.format_price raw_max_market_sell_price}
    #{padstr("total untaxed profit")}#{@cli.green PriceCalculator.format_price raw_profit_with_procs} [max: #{@cli.green PriceCalculator.format_price(raw_profit_with_procs * max_potion_count)}]
    #{padstr("total taxed profit")}#{@cli.green PriceCalculator.format_price taxed_sell_profit_after_procs} [max: #{@cli.green PriceCalculator.format_price(max_taxed_sell_profit_after_procs)}]

"
      { information: information, max_profit: max_taxed_sell_profit_after_procs }
    end
  end

  def seconds_to_str(seconds)
    ["#{(seconds / 3600).floor}h", "#{(seconds / 60 % 60).floor}m", "#{(seconds % 60).floor}s"]
      .select { |str| str =~ /[1-9]/ }.join(" ")
  end

  def padstr(str, space_around = ' ', len = 32, pad_with = '.')
    padded = "#{str}#{space_around}"
    "#{padded.ljust(len, pad_with)}#{space_around}"
  end

  def mapper(item)
    item[:price].to_i * item[:quant].to_i
  end

  def get_stock_count(item_info)
    return Float::INFINITY if item_info.dig(:is_npc_item)

    item_info[:total_in_stock].to_i.zero? ? item_info[:count].to_i : item_info[:total_in_stock].to_i
  end

  # async def do_if_category_matches(options, &procedure)
  #   procedure.call.wait if options[:subcategory] == options[:subcat_to_match] || options[:all_subcategories]
  # end

  def do_if_category_matches(options, &procedure)
    procedure.call if options[:all_subcategories]
    procedure.call if options[:subcategory] == options[:subcat_to_match]
  end
end

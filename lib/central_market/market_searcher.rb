# frozen_string_literal: true

require 'httparty'
require 'json'

require_relative '../utils/constants'
require_relative '../utils/price_calculator'
require_relative '../utils/recipe_logger'
require_relative '../utils/npc_item_index'
require_relative './category_search_options'

# search for information on recipes in given categories
class MarketSearcher
  include Utils
  include MarketSearchTools

  def initialize(region, cli)
    @root_url = ENVData.get_root_url region
    @region_subdomain = CLIConstants::REGION_DOMAINS[region.to_sym].split('.')[1..].join('.')
    @market_list_url = "#{@root_url}#{ENVData::WORLD_MARKET_LIST}"
    @market_search_url = "#{@root_url}#{ENVData::MARKET_SEARCH_LIST}"
    @market_sub_url = "#{@root_url}#{ENVData::MARKET_SUB_LIST}"
    @market_sell_buy_url = "#{@root_url}#{ENVData::MARKET_SELL_BUY_INFO}"
    @cli = cli
    @ingredient_cache = {}
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
        sleep 2
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
              file.write(error&.full_message || error)
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
            out_of_stock_items.push(item_price_info[:name].downcase)
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
            total_trade_count: item_price_info[:total_trade_count].to_i,
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

      # harmony draught recipe produces 10
      if item[:id].to_s == '1399'
        average_procs = 10
      end
    end

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

    average_procs = 1 if selected_recipe.find { |a| a[:name].downcase == 'blue reagent' } != nil

    # remove recipes where one ingredient is used twice
    # this usually happens because of incorrect substitution being
    # found from bdocodex. or maybe they're not incorrect, and there
    # are some seriously mysterious alchemy recipes out there...
    ingredients_already_appeared = []
    filtered_selected_recipe = selected_recipe.filter do |ingredient|
      # set procs to 1 if blue reagent required
      average_procs = 1 if ingredient[:name].downcase == 'blue reagent'
      return false if ingredients_already_appeared.include? ingredient[:name]
      ingredients_already_appeared.push(ingredient[:name])
      true
    end

    return nil if filtered_selected_recipe.length != selected_recipe.length

    total_ingredient_cost = (selected_recipe.map { |ing| ing[:price] * ing[:quant] }.sum / average_procs).floor
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
      #
      max_taxed_sell_profit_after_procs = (PriceCalculator.calculate_taxed_price(item_market_sell_price * max_potion_count) - total_max_ingredient_cost) * average_procs

      return nil if max_taxed_sell_profit_after_procs.to_s.downcase == 'nan'
      return nil if max_taxed_sell_profit_after_procs < 0

      recipe_logger = RecipeLogger.new @cli
      results = recipe_logger.log_recipe_data(item, selected_recipe, max_potion_count, item_market_sell_price, total_ingredient_cost, average_procs, total_max_ingredient_cost, raw_max_market_sell_price, max_taxed_sell_profit_after_procs, raw_profit_with_procs, taxed_sell_profit_after_procs)
      { information: results[:recipe_info], max_profit: max_taxed_sell_profit_after_procs, silver_per_hour: results[:silver_per_hour] }
    end
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

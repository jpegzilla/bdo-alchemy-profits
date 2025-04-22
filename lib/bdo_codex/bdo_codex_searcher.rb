# frozen_string_literal: true

require 'json'
require 'httparty'
require 'nokogiri'
require 'awesome_print'

require_relative '../utils/user_cli'
require_relative '../utils/array_utils'
require_relative '../utils/hash_cache'

# some variables that are necessary for parsing bdocodex data
class BDO_CODEX_UTILS
  BDOCODEX_QUERY_DATA_KEY = 'aaData'
  RECIPE_COLUMNS = [
    'id',
    'icon',
    'title',
    'type',
    'skill level',
    'exp',
    'materials',
    'total weight of materials',
    'products',
    'all ingredients',
  ]
end

# used to retrieve items from BDOCodex
class BDOCodexSearcher
  include Utils

  RECIPE_INGREDIENTS_INDEX = 2

  def initialize(region, lang, cli, hyper_aggressive = false)
    @region = region
    @root_url = ENVData.get_root_url region
    @cli = cli
    @region_lang = lang
    @cache = HashCache.new ENVData::BDO_CODEX_CACHE
    @hyper_aggressive = hyper_aggressive
  end

  def get_recipe_url(url)
    begin
      data = HTTParty.get(
        URI(url),
        headers: ENVData::REQUEST_OPTS[:bdo_codex_headers],
        content_type: 'application/x-www-form-urlencoded'
      )

      JSON.parse data unless data.body.nil? or data.body.empty?
    rescue
      {}
    end
  end

  # TODO: is there a way to get rid of all these nested loops in this class?
  def get_recipe_substitutions(recipe_with_substitute_ids, all_potion_recipes, name)
    all_recipe_substitutions = []
    all_potion_recipes.each do |recipe|
      original_recipe = recipe[RECIPE_INGREDIENTS_INDEX]
      original_ingredient_indices = original_recipe.map do |item|
        recipe_with_substitute_ids.find_index { |id| id == item[:id] }
      end

      chunked_by_substitution_groups = []

      original_ingredient_indices.each.with_index do |_arr_index, idx|
        slice_from = [0, original_ingredient_indices[idx].to_i].max
        slice_to = slice_from + 1
        slice_to = original_ingredient_indices[idx + 1] if @hyper_aggressive
        # set hyper_aggressive to true if you want to check every
        # permutation of this recipe, with all substitutions considered
        # this will be exceedingly slow and generate hundreds and hundreds
        # of post requests, hammering the black desert market api and
        # potentially causing incapsula to GET YOU (block your IP)

        chunked_by_substitution_groups.push(
          recipe_with_substitute_ids[slice_from..(slice_to ? slice_to - 1 : -1)]
        )
      end

      original_recipe_length = original_recipe.length
      permutated_chunks = ArrayUtils.deep_permute chunked_by_substitution_groups, original_recipe_length

      permutated_chunks.each do |id_list|
        recipe_with_new_items = [*recipe]
        recipe_with_new_items[RECIPE_INGREDIENTS_INDEX] = [*recipe][RECIPE_INGREDIENTS_INDEX].map.with_index do |recipe_list, idx|
          { **recipe_list, id: id_list[idx] }
        end

        all_recipe_substitutions.push recipe_with_new_items
      end
    end

    # 1 in elem[1] is the index of the recipe name
    all_recipe_substitutions.filter { |elem| elem[1].downcase == name.downcase }
  end

  def parse_raw_recipe(recipe_data, item_name)
    item_with_ingredients = recipe_data.dig(BDO_CODEX_UTILS::BDOCODEX_QUERY_DATA_KEY)

    if item_with_ingredients
      recipe_with_substitute_ids = item_with_ingredients.map do |arr|
        arr.filter.with_index { |_, idx| idx == 9 }
         .map { |item| JSON.parse(item) }
         .first
      end.first

      all_potion_recipes = item_with_ingredients.map do |arr|
        mapped_item_data = arr
          .filter.with_index { |_, idx | !BDO_CODEX_UTILS::RECIPE_COLUMNS[idx].nil? }
          .map.with_index do |raw_element, idx|
            category = BDO_CODEX_UTILS::RECIPE_COLUMNS[idx]

            next if ['skill level', 'exp', 'type', 'icon', 'total weight of materials'].include? category

            element = Nokogiri::HTML5 raw_element.to_s

            result = {
              :category => category,
              :element => element
            }

            result[:element] = element.text.downcase if category == 'title'

            result[:element] = element.text.downcase if category == 'id'

            if %w[materials products].include? category
              quants = element.text.scan(/\](\d+)/im).map { |e| e[0].to_i }

              ids = element.to_s.scan(/#{@region_lang}\/item\/(\d+)/).map { |e| e[0].to_i }
              result[:element] = ids.map.with_index { |id, i| { id: id, quant: quants[i]} }.flatten
            end

            result
        end

        filtered_item_data = mapped_item_data
                               .compact
                               .filter { |e| %w[id title materials products].include? e[:category] }
                               .map { |e| e[:element] }

        filtered_item_data
      end

      get_recipe_substitutions recipe_with_substitute_ids, all_potion_recipes, item_name
    end
  end

  def get_item_recipes(item_id, item_name)
    recipe_direct_url = "https://bdocodex.com/query.php?a=recipes&type=product&item_id=#{item_id}&l=#{@region_lang}"
    mrecipe_direct_url = "https://bdocodex.com/query.php?a=mrecipes&type=product&item_id=#{item_id}&l=#{@region_lang}"
    # houserecipe_direct_url = "https://bdocodex.com/query.php?a=designs&type=product&item_id=#{item_id}&l=#{@region_lang}"

    # TODO: there MUST be a better way to determine which recipe to use, rather than just trying them both.
    begin
      direct_data = get_recipe_url recipe_direct_url

      if !direct_data || direct_data.empty?
        mrecipe_data = get_recipe_url mrecipe_direct_url

        return parse_raw_recipe mrecipe_data, item_name
      else
        parsed = parse_raw_recipe direct_data, item_name

        if !parsed || parsed.empty?
          mrecipe_data = get_recipe_url mrecipe_direct_url

          return parse_raw_recipe mrecipe_data, item_name
        end

        parsed
      end
    rescue StandardError => error
      puts @cli.red("if you're not messing with the code, you should never see this. get_item_recipes broke.")

      File.open(ENVData::ERROR_LOG, 'a+') do |file|
        file.write(error.full_message)
        file.write("\n\r")
      end

      []
    end
  end

  # m_recipes_first may be useful if a lot of recipes aren't working
  # refer to the original javascript implementation of
  # searchCodexForRecipes
  # m_recipes_first should be used to hit the /mrecipe version of a recipe
  # for manufacturing-type recipes
  def search_codex_for_recipes(item, m_recipes_first)
    item_id = item[:main_key]
    item_name = item[:name]
    item_index = "#{item_id} #{item[:name]}"
    potential_cached_recipes = @cache.read item_index
    cache_data = {}

    # TODO: remove this check
    # return unless item_name.downcase == 'harmony draught'

    unless potential_cached_recipes.to_a.empty?
      recipe_to_maybe_select = potential_cached_recipes.filter { |elem| elem[1].downcase == item_name.downcase }
      return recipe_to_maybe_select unless recipe_to_maybe_select.empty?
    end

    recipes = get_item_recipes item_id, item_name
    cache_data[item_index] = recipes

    @cache.write cache_data

    recipes
  end

  # pass in a list of items as retrieved from the central market API
  def get_item_codex_data(item_list)
    recipes = []

    # newline because vipiko is about to start carriage returning
    puts
    item_list.each.with_index do |item_hash, index|
      item = item_hash.transform_keys { |key|
        key.gsub(/(.)([A-Z])/,'\1_\2').downcase.to_sym
      }

      next unless item[:main_key]

      begin
        search_results = search_codex_for_recipes item, false

        if search_results
          # res[0] is the recipe ID
          all_recipes_for_item = search_results.map { |res|
            recipe_array = [res[0], res[RECIPE_INGREDIENTS_INDEX]]
            recipe_array
          }

          @cli.vipiko_overwrite "(#{index + 1} / #{item_list.length}) let's read the recipe for #{@cli.yellow "[#{item[:name].downcase}]"}. hmm..."

          stock_count = item[:total_in_stock].to_i.zero? ? item[:count].to_i : item[:total_in_stock].to_i
          recipe_hash = {
            name: item[:name],
            recipe_list: all_recipes_for_item,
            price: item[:price_per_one],
            id: item[:main_key],
            total_trade_count: item[:total_trade_count],
            total_in_stock: stock_count,
            main_category: item[:main_category],
            sub_category: item[:sub_category]
          }

          recipes.push recipe_hash
        end
      rescue StandardError => error
        puts @cli.red("if you're not messing with the code, you should never see this. get_item_codex_data broke.")

        File.open(ENVData::ERROR_LOG, 'a+') do |file|
          file.write(error.full_message)
          file.write("\n\r")
        end

        next
      end
    end

    recipes
  end
end

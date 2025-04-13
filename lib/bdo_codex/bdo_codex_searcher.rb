# frozen_string_literal: true

require_relative '../../utils/cli_utils/user_cli'

require 'json'

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
  def initialize(region, cli)
    @region = region
    @root_url = ENVData.get_root_url region
    @cli = cli
  end

  def get_bdo_codex_cache
    file_content = File.read(ENVData::BDO_CODEX_CACHE)

    begin
      return JSON.parse file_content unless file_content.empty?

      {}
    rescue
      {}
    end
  end

  def search_codex_for_recipes(item, m_recipes_first)
    item_index = "#{item[:main_key]} #{item[:name]}"

    # File.open(ENVData::BDO_CODEX_CACHE, 'w') do |file|
    #   data.map do |item|
    #     item_map[item['mainKey']] = item
    #   end
    #
    #   file.write item_map.to_json
    # end

    pp item_index
  end

  # pass in a list of items as retrieved from the central market API
  def get_item_codex_data(item_list)
    pp item_list
    recipes = []

    item_list.each do |item|
      item_hash = item.transform_keys { |key|
        key.gsub(/(.)([A-Z])/,'\1_\2').downcase.to_sym
      }

      next unless item_hash[:main_key]

      all_recipes_for_item = []
      codex_cache = get_bdo_codex_cache

      begin
        search_codex_for_recipes item, false
      rescue StandardError => error
        @cli.red "if you're not messing with the code, you should never see this. get_item_codex_data broke."

        File.open(ENVData::ERROR_LOG, 'w') do |file|
          file.write('\n\n', error.to_s)
        end

        next
      end

      pp item_hash
    end
  end
end

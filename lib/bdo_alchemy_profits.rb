#!/usr/bin/env ruby
# frozen_string_literal: true

# MIT License
#
# Copyright (c) 2025 jpegzilla
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'optparse'
require 'httparty'

require_relative './utils/user_cli'
require_relative './central_market/market_searcher'
require_relative './bdo_codex/bdo_codex_searcher'

# main module for bdoap. contains the BDOAlchemyProfits class
module BDOAP
  # used to search for profitable alchemy recipes
  class BDOAlchemyProfits
    include Utils

    def start_enhance(search_string, enhance_starting_level, region, cli)
      items_at_level = []
      root_url = ENVData.get_root_url region
      search_url = "#{root_url}#{ENVData::MARKET_SEARCH_LIST}"
      sub_url = "#{root_url}#{ENVData::MARKET_SUB_LIST}"
      category_opts = {
        url: search_url,
        query_string: "#{ENVData::RVT}&searchText=#{URI.encode_www_form_component search_string}",
        update: ->(data) { data['list'] }
      }

      data = HTTParty.post(
        URI(category_opts[:url].to_s),
        headers: ENVData.get_central_market_headers(ENVData.get_incap_cookie(@region_subdomain)),
        body: category_opts[:query_string],
        content_type: 'application/x-www-form-urlencoded'
      )

      resolved = category_opts[:update].call(data) if data

      return unless resolved

      resolved.each do |item|
        subdata = HTTParty.post(
          URI(sub_url),
          headers: ENVData.get_central_market_headers(ENVData.get_incap_cookie(@region_subdomain)),
          body: "#{ENVData::RVT}&mainKey=#{item['mainKey']}&usingCleint=0",
          content_type: 'application/x-www-form-urlencoded'
        )

        sleep rand

        if subdata&.dig('detailList')
          level_map = {
            0 => 0,
            1 => 1,
            2 => 2,
            3 => 3,
            4 => 4,
            5 => 5,
            6 => 6,
            7 => 7,
            8 => 8,
            9 => 9,
            10 => 10,
            11 => 11,
            12 => 12,
            13 => 13,
            14 => 14,
            15 => 15,
            16 => 16,
            17 => 17,
            18 => 18,
            19 => 19,
            20 => 20,
          }

          level_map_to_bdo = {
            0 => 0,
            1 => 1,
            2 => 2,
            3 => 3,
            4 => 4,
            5 => 5,
            6 => 6,
            7 => 7,
            8 => 8,
            9 => 9,
            10 => 10,
            11 => 11,
            12 => 12,
            13 => 13,
            14 => 14,
            15 => 15,
            16 => 'PRI',
            17 => 'DUO',
            18 => 'TRI',
            19 => 'TET',
            20 => 'PEN',
          }

          result = subdata['detailList'] .find { |e| e['subKey'].to_s == level_map[enhance_starting_level.to_i].to_s }
          if result
            constructed = "    #{result['count']} #{cli.yellow result['name'].downcase} @ #{level_map_to_bdo[result['subKey']]}"
            items_at_level.push constructed unless result['count'].to_i == 0
          end
        end
      end

      puts "\nthe results are in!\n"
      items_at_level.each { |item| puts item }
      puts
    end

    # begin the configuration and search process
    def start_cli(search_string = nil, enhance_starting_level = nil, enhancing = false)
      begin
        options = {}

        OptionParser.new do |opt|
          opt.on('--silent', '-s') { options[:silent] = true }
        end.parse!

        # option setup
        cli = UserCLI.new options

        unless enhancing
          category = cli.choose_category
          cli.end_cli if category == 'exit'
        end

        region = cli.choose_region
        cli.end_cli if region == 'exit'

        # start enhancing
        if enhancing && search_string && enhance_starting_level
          start_enhance(search_string, enhance_starting_level, region, cli)
          return
        end

        lang = cli.choose_lang
        cli.end_cli if lang == 'exit'
        aggression = cli.choose_aggression
        cli.end_cli if aggression == 'exit'
        free_ingredients = cli.choose_free_ingredients
        show_out_of_stock = cli.choose_show_out_of_stock

        if aggression == 'hyperaggressive'
          puts cli.orange("\nWARN: hyperagressive mode is RISKY AND SLOW. this will evaluate every substitution for every recipe. hammers apis violently. you will get rate limited. you will get IP blocked. her royal holiness imperva incapsula WILL get you. select if you know what all that stuff means and you are ok with waiting 20 minutes.")
        end

        # start searching
        cli.vipiko("\n♫ let's see if #{cli.yellow category} alchemy items are profitable in #{cli.yellow region}!")

        market_searcher = MarketSearcher.new(region, cli, free_ingredients)

        market_item_list = market_searcher.get_alchemy_market_data category

        cli.vipiko("I'll look for #{cli.yellow(market_item_list.length.to_s)} item#{
          market_item_list.empty? || market_item_list.length > 1 ? 's' : ''
        } in #{category == 'all' ? cli.yellow('all categories'): "the #{cli.yellow category} category"}!")

        bdo_codex_searcher = BDOCodexSearcher.new(region, lang, cli, aggression == 'hyperaggressive')

        item_codex_data = bdo_codex_searcher.get_item_codex_data market_item_list

        recipe_prices = market_searcher.get_all_recipe_prices item_codex_data, category

        mapped_prices = recipe_prices.reverse.sort_by { |recipe| recipe[:gain].to_i }.map { |recipe| recipe[:information] }

        out_of_stock = recipe_prices.dig(0, :out_of_stock) || []
        out_of_stock_list = ""
        out_of_stock.each { |item| out_of_stock_list += "\n\t  #{cli.yellow item}" }

        if mapped_prices.length > 0
          cli.vipiko_overwrite "done!"
          puts "\n\n"
          puts mapped_prices
        else
          cli.vipiko_overwrite "none of those recipes look profitable right now...let's go gathering!\n\n"
        end

        puts "      items that were out of stock: #{out_of_stock_list}" if show_out_of_stock && out_of_stock_list.length > 0
      rescue Interrupt => e
        puts "\n\nstopping!"
      end
    end
  end
end

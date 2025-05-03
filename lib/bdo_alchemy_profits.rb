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

require_relative './utils/user_cli'
require_relative './central_market/market_searcher'
require_relative './bdo_codex/bdo_codex_searcher'

# main module for bdoap. contains the BDOAlchemyProfits class
module BDOAP
  # used to search for profitable alchemy recipes
  class BDOAlchemyProfits
    include Utils

    # begin the configuration and search process
    def start_cli
      begin
        options = {}

        OptionParser.new do |opt|
          opt.on('--silent', '-s') { options[:silent] = true }
        end.parse!

        # option setup
        cli = UserCLI.new options

        category = cli.choose_category
        cli.end_cli if category == 'exit'
        region = cli.choose_region
        cli.end_cli if region == 'exit'
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

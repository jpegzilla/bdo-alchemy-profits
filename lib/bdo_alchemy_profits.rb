# frozen_string_literal: true

require 'optparse'

require_relative './utils/user_cli'
require_relative './central_market/market_searcher'
require_relative './bdo_codex/bdo_codex_searcher'

class BDOAlchemyProfits
  include Utils

  def start_cli
    options = {}

    OptionParser.new do |opt|
      opt.on('--silent', '-s') { options[:silent] = true }
    end.parse!

    cli = UserCLI.new options

    # option setup

    category = cli.choose_category

    cli.end_cli if category == 'exit'

    region = cli.choose_region

    cli.end_cli if region == 'exit'

    lang = cli.choose_lang

    cli.end_cli if lang == 'exit'

    aggression = cli.choose_aggression

    cli.end_cli if aggression == 'exit'

    if aggression == 'hyperaggressive'
      puts cli.orange("\nWARN: hyperagressive mode is RISKY AND SLOW. this will evaluate every substitution for every recipe. hammers apis violently. you will get rate limited. you will get IP blocked. her royal holiness imperva incapsula WILL get you. select if you know what all that stuff means and you are ok with waiting 20 minutes.")
    end

    # start searching

    cli.vipiko("\n♫ let's see if #{cli.yellow category} alchemy items are profitable in #{cli.yellow region}!")

    market_searcher = MarketSearcher.new region, cli

    market_item_list = market_searcher.get_alchemy_market_data category

    cli.vipiko("\nI'll look for #{cli.yellow(market_item_list.length)} item#{
      market_item_list.empty? || market_item_list.length > 1 ? 's' : ''
    } in #{category == 'all' ? cli.yellow('all categories'): "the #{cli.yellow category} category"}!")

    bdo_codex_searcher = BDOCodexSearcher.new(region, lang, cli, aggression == 'hyperaggressive')

    item_codex_data = bdo_codex_searcher.get_item_codex_data market_item_list

    recipe_prices = market_searcher.get_all_recipe_prices item_codex_data, category

    mapped_prices = recipe_prices.sort_by { |recipe| recipe[:silver_per_hour].to_i }.map { |recipe| recipe[:information] }

    puts mapped_prices
  end
end

# frozen_string_literal: true

require 'optparse'

require_relative 'utils/cli_utils/user_cli'
require_relative 'lib/central_market/market_searcher'
require_relative 'lib/bdo_codex/bdo_codex_searcher'

options = {}

OptionParser.new do |opt|
  opt.on('--silent', '-s') { options[:silent] = true }
end.parse!

cli = UserCLI.new options

category = cli.choose_category

cli.end_cli if category == 'exit'

region = cli.choose_region

cli.end_cli if region == 'exit'

cli.vipiko("\n♫ let's see if #{cli.yellow category} alchemy items are profitable in #{cli.yellow region}!")

market_searcher = MarketSearcher.new region

market_item_list = market_searcher.get_alchemy_market_data category

cli.vipiko("\nI'll look for #{cli.yellow(market_item_list.length)} item#{
  market_item_list.empty? || market_item_list.length > 1 ? 's' : ''
} in #{category == 'all' ? cli.yellow('all categories'): "the #{cli.yellow category} category"}!")

bdo_codex_searcher = BDOCodexSearcher.new(region, cli)

bdo_codex_searcher.get_item_codex_data market_item_list

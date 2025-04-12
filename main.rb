# frozen_string_literal: true

require 'optparse'

require_relative './utils/user_cli'
require_relative './utils/central_market/market_searcher'

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

data = market_searcher.get_alchemy_market_data category

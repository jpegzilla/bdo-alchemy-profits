# frozen_string_literal: true

require 'tty-prompt'

require_relative 'lib/bdo_alchemy_profits'

prompt = TTY::Prompt.new

profit_calculator = BDOAP::BDOAlchemyProfits.new

options = %w[all enhancing]

enhancing = prompt.select('collate all prices or search for enhancing?', { cycle: true, filter: true }) do |menu|
  menu.enum '.'
  menu.help "use arrow keys or numbers 1-#{options.length} to navigate, press enter to select. type to search."
  options.each do |string|
    menu.choice string, string
  end
end

if enhancing == 'enhancing'
  search_string = prompt.ask('enter an item name to search for.')
  starting_level = prompt.ask('starting enhancement level? (0-20)')
  profit_calculator.start_cli(search_string, starting_level, true)
else
  profit_calculator.start_cli
end

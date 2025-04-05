# frozen_string_literal: true

require 'tty-prompt'
require 'rainbow'

# offensive 'category 35, subcategory 1',
# defensive: 'category 35, subcategory 2',
# functional: 'category 35, subcategory 3',
# potion: 'category 35, subcategory 5',
# other: 'category 35, subcategory 8',
# blood: 'searches "s blood"',
# oil: 'searches "oil of"',
# alchemy stone: 'searches "stone of"',
# reagent: 'searches "reagent"',
# black stone: 'category 30, subcategory 1',
# magic crystal: 'searches "magic crystal"',
# all: 'collates everything above'

# asks the questions and fires up the recipe search
class UserCLI
  def initialize
    @options = [
      'offensive',
      'defensive',
      'functional',
      'potion',
      'other',
      'blood',
      'oil',
      'alchemy stone',
      'reagent',
      'black stone',
      'magic crystal',
      'all'
    ]

    @prompt = TTY::Prompt.new
  end

  def yellow(string)
    Rainbow(string).yellow
  end

  def red(string)
    Rainbow(string).red
  end

  def green(string)
    Rainbow(string).green
  end

  def ask
    puts "\n♫ hello! oh? you want to sell #{yellow 'potions'} today? that sounds like fun!\n"

    @prompt.select('which category shall we try to make today?', @options, cycle: true)
  end

  def stop
    puts
    @prompt.keypress('(press any key to exit)')

    exit
  end
end

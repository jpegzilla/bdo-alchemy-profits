# frozen_string_literal: true

require 'tty-prompt'
require 'rainbow'

# asks the questions and fires up the recipe search
module Utils
  class UserCLI
    attr_accessor :silent

    # @param [Hash] options options from ARGV
    def initialize(options)
      @silent = options[:silent]
      @prompt = TTY::Prompt.new
    end

    # uses Rainbow to make a string yellow
    # @param [String] string the string to print
    # @return [String]
    def yellow(string)
      Rainbow(string).yellow
    end

    # uses Rainbow to make a string orange
    # @param [String] string the string to print
    # @return [String]
    def orange(string)
      Rainbow(string).orange
    end

    # uses Rainbow to make a string red
    # @param [String] string the string to print
    def red(string)
      Rainbow(string).red
    end

    # uses Rainbow to make a string green
    # @param [String] string the string to print
    def green(string)
      Rainbow(string).green
    end

    # log, but cutely
    # @param [String] string the string to print
    def vipiko(string)
      puts string unless @silent
    end

    # calls print on a string preceded by a line erase and carriage return
    # also calls $stdout.flush
    # @param [String] string the string to print
    def vipiko_overwrite(string)
      print "\033[2K\r#{string}"
      $stdout.flush
    end

    # log for other stuff
    # @param [String] string the string to print
    def log(string)
      puts string
    end

    # adds usage info to a tty-prompt menu
    # @param menu the tty-prompt menu object in the select() block
    # @param [Hash] options the hash of options
    def add_menu_info(menu, options)
      menu.enum '.'
      menu.help "use arrow keys or numbers 1-#{options.length} to navigate, press enter to select. type to search."
    end

    # prompt the user to choose the category to search through
    # @return [String] the selected category
    def choose_category
      vipiko "\n♫ hello! oh? you want to sell #{yellow 'potions'} today? that sounds like fun!\n\n"

      option = @prompt.select('which category shall we try to make today?', { cycle: true, filter: true }) do |menu|
        add_menu_info(menu, CLIConstants::CATEGORY_OPTIONS)
        CLIConstants::CATEGORY_OPTIONS.each do |k, v|
          menu.choice "#{k} #{Rainbow(v).faint.white}", k
        end
      end

      option.to_s
    end

    # prompt the user to choose the region to search within
    # @return [String] the selected region
    def choose_region
      option = @prompt.select('and where are you in the world?', { cycle: true, filter: true }) do |menu|
        add_menu_info(menu, CLIConstants::REGION_DOMAINS)
        CLIConstants::REGION_DOMAINS.each do |k, v|
          menu.choice "#{k} #{Rainbow(v).faint.white}", k
        end
      end

      option.to_s
    end

    # prompt the user to choose the language to show results in
    # @return [String] the selected language
    def choose_lang
      option = @prompt.select('what language would you like to search bdocodex with?', { cycle: true, filter: true }) do |menu|
        add_menu_info(menu, CLIConstants::REGION_LANGUAGES)
        CLIConstants::REGION_LANGUAGES.each do |k, v|
          menu.choice "#{k} #{Rainbow(v).faint.white}", k
        end
      end

      option.to_s
    end

    # prompt the user to choose the aggression to search with
    # higher aggression will cause all recipe permutations / item substitutions to be considered in profit calculation
    # @return [String] the selected aggression level
    def choose_aggression
      option = @prompt.select('what aggression level would you like to search for recipes with?', { cycle: true, filter: true }) do |menu|
        add_menu_info(menu, CLIConstants::AGGRESSION_LEVELS)
        CLIConstants::AGGRESSION_LEVELS.each do |k, v|
          menu.choice "#{k} #{Rainbow(v).faint.white}", k
        end
      end

      option.to_s
    end

    # prompt the user to input item ids that they already have a lot of
    # the script will consider these as "free" and set their cost to zero and stock to infinite
    # @return [Array] the selected item ids
    def choose_free_ingredients
      option = @prompt.ask('what item ids do you have a lot of already? we can consider that in the final cost calculations.', convert: :list, default: [])

      option&.to_a if option&.to_a.is_a? Array
    end

    # prompt the user to decide whether to show or hide a list of out of stock items
    # @return [Boolean] true to show out of stock items, false to hide
    def choose_show_out_of_stock
      @prompt.yes?('finally, would you like to show the items that were out of stock?')
    end

    # ends the program
    def end_cli
      vipiko "\nnever mind, let's do some #{yellow 'cooking'} together instead! ♫\n\n"

      exit
    end
  end
end

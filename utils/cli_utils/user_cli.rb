# frozen_string_literal: true

require 'tty-prompt'
require 'rainbow'

# asks the questions and fires up the recipe search
class UserCLI
  attr_accessor :silent

  def initialize(options)
    @silent = options[:silent]
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

  def orange(string)
    Rainbow(string).orange
  end

  def cyan(string)
    Rainbow(string).cyan
  end

  # log, but cutely
  def vipiko(string)
    puts string unless @silent
  end

  def vipiko_overwrite(string)
    print "\033[2K\r#{string}"
    $stdout.flush
  end

  # log for other stuff
  def log(string)
    puts string
  end

  def add_menu_info(menu, options)
    menu.enum '.'
    menu.help "use arrow keys or numbers 1-#{options.length} to navigate, press enter to select. type to search."
  end

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

  def choose_region
    option = @prompt.select('and where are you in the world?', { cycle: true, filter: true }) do |menu|
      add_menu_info(menu, CLIConstants::REGION_DOMAINS)
      CLIConstants::REGION_DOMAINS.each do |k, v|
        menu.choice "#{k} #{Rainbow(v).faint.white}", k
      end
    end

    option.to_s
  end

  def choose_lang
    option = @prompt.select('what language would you like to search bdocodex with?', { cycle: true, filter: true }) do |menu|
      add_menu_info(menu, CLIConstants::REGION_LANGUAGES)
      CLIConstants::REGION_LANGUAGES.each do |k, v|
        menu.choice "#{k} #{Rainbow(v).faint.white}", k
      end
    end

    option.to_s
  end

  def choose_aggression
    option = @prompt.select('finally, what aggression level would you like to search for recipes with?', { cycle: true, filter: true }) do |menu|
      add_menu_info(menu, CLIConstants::AGGRESSION_LEVELS)
      CLIConstants::AGGRESSION_LEVELS.each do |k, v|
        menu.choice "#{k} #{Rainbow(v).faint.white}", k
      end
    end

    option.to_s
  end

  def end_cli
    vipiko "\nnever mind, let's do some #{yellow 'cooking'} together instead! ♫\n\n"

    @prompt.keypress('(press any key to exit)')

    exit
  end
end

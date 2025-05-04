# frozen_string_literal: true

module Utils
  # log recipe information
  class RecipeLogger
    def initialize(cli)
      @cli = cli
    end

    def padstr(str, space_around = ' ', len = 32, pad_with = '.')
      padded = "#{str}#{space_around}"
      "#{padded.ljust(len, pad_with)}#{space_around}"
    end

    def seconds_to_str(seconds)
      return seconds if seconds == Float::INFINITY
      ["#{(seconds / 3600).floor}h", "#{(seconds / 60 % 60).floor}m", "#{(seconds % 60).floor}s"]
        .select { |str| str =~ /[1-9]/ }.join(" ")
    end

    def log_recipe_data(item, selected_recipe, max_potion_count, item_market_sell_price, total_ingredient_cost, average_procs, total_max_ingredient_cost, raw_max_market_sell_price, max_taxed_sell_profit_after_procs, raw_profit_with_procs, taxed_sell_profit_after_procs)
      stock_counts = []

      selected_recipe.each do |ingredient|
        amount_required_for_max_potions = max_potion_count * ingredient[:quant]
        ingredient_market_sell_price = ingredient[:price].to_i

        next if (amount_required_for_max_potions * ingredient_market_sell_price) < 0

        raw_max_ingredient_sell_price = ingredient[:price] * max_potion_count
        formatted_price = @cli.yellow PriceCalculator.format_price ingredient_market_sell_price
        formatted_max_price = @cli.yellow PriceCalculator.format_price raw_max_ingredient_sell_price
        formatted_potion_amount = @cli.yellow PriceCalculator.format_num(ingredient[:quant]).rjust(4, ' ')
        formatted_ingredient_id = "[#{ingredient[:id]}]".rjust(7, ' ')
        formatted_max_potion_amount = @cli.yellow PriceCalculator.format_num max_potion_count * ingredient[:quant]
        formatted_stock_count = @cli.yellow PriceCalculator.format_num ingredient[:total_in_stock]
        formatted_npc_information = ingredient[:is_npc_item] ? @cli.yellow(" (sold by #{ingredient[:npc_type]} npcs)") : ''
        if ingredient[:exchange_with_npc]
          formatted_npc_information = @cli.yellow(" (exchange at least #{ingredient[:must_exchange]} #{ingredient[:exchange_with_names].join(' / ')} for #{ingredient[:exchanging_grants] * ingredient[:must_exchange]} with #{ingredient[:exchange_with_npc]})")
        end

        formatted_enhance_level = ['0', ''].include?(ingredient[:enhance_level].to_s) ? ' ' : " +#{ingredient[:enhance_level]} "

        stock_counts.push "#{formatted_potion_amount} [max: #{formatted_max_potion_amount}] #{formatted_ingredient_id}#{@cli.yellow "#{formatted_enhance_level}#{ingredient[:name].downcase}: #{formatted_stock_count}"} in stock#{formatted_npc_information}. price: #{formatted_price} [for max: #{formatted_max_price}]"
      end

      market_stock_string = item[:total_in_stock] > 2000 ? @cli.red(PriceCalculator.format_num(item[:total_in_stock])) : @cli.green(PriceCalculator.format_num(item[:total_in_stock]))

      trade_count_string = item[:total_trade_count] < 10_000_000 ? @cli.red(PriceCalculator.format_num(item[:total_trade_count])) : @cli.green(PriceCalculator.format_num(item[:total_trade_count]))

      ratio_string = if item[:total_trade_count] / (item[:total_in_stock].zero? ? 1 : item[:total_in_stock]) < 50_000
                       @cli.red('bad')
                     else
                       @cli.green('good')
                     end

      estimated_craft_time = 1.2
      calculated_time = max_potion_count * estimated_craft_time
      crafting_time_string = calculated_time > 21600 ? @cli.red((seconds_to_str(calculated_time))) : @cli.green((seconds_to_str(calculated_time)))
      silver_per_hour = PriceCalculator.format_price(max_taxed_sell_profit_after_procs.to_f / (calculated_time.to_f / 3600))
      estimated_craft_time_string = "(accounting for average #{estimated_craft_time}s / craft due to typical server delay)"

      if selected_recipe.find { |ingredient| ingredient[:is_m_recipe] == true }
        crafting_time_string = @cli.yellow "unknown: this is a processing recipe!"
        estimated_craft_time_string = ''
        silver_per_hour = 'unknown'
      end

      return_on_investment = max_taxed_sell_profit_after_procs.to_f / total_max_ingredient_cost.to_f
      formatted_roi = return_on_investment > 1 ? @cli.green("#{return_on_investment.round(2)}x") : @cli.red("#{return_on_investment.round(2)}x" )

      information = "    #{@cli.yellow "[#{item[:id]}] [#{item[:name].downcase}], recipe id: #{selected_recipe[0][:for_recipe_id]}"}

      #{padstr("market price of item")}#{@cli.yellow PriceCalculator.format_price item_market_sell_price}
      #{padstr("market stock of item")}#{market_stock_string}
      #{padstr("total trades of item")}#{trade_count_string}
      #{padstr("ratio")}#{ratio_string}
      #{padstr("you can craft")}#{@cli.yellow PriceCalculator.format_num max_potion_count}
      #{padstr("theoretical max output")}#{@cli.yellow PriceCalculator.format_num(max_potion_count * average_procs)}
      #{padstr("cost of ingredients")}#{@cli.yellow PriceCalculator.format_price total_ingredient_cost} (accounting for average #{average_procs} / craft)
      #{padstr("max cost of ingredients")}#{@cli.yellow PriceCalculator.format_price total_max_ingredient_cost} (accounting for average #{average_procs} / craft)
      #{padstr("time to craft max")}#{crafting_time_string} #{estimated_craft_time_string}

  \t#{stock_counts.join "\n\t"}

      total income for max items before cost subtraction #{@cli.green PriceCalculator.format_price raw_max_market_sell_price}
      #{padstr("total taxed silver per hour")}#{@cli.green silver_per_hour } silver / hour
      #{padstr("total untaxed profit")}#{@cli.green PriceCalculator.format_price raw_profit_with_procs} [max: #{@cli.green PriceCalculator.format_price(raw_profit_with_procs * max_potion_count)}]
      #{padstr("total taxed profit")}#{@cli.green PriceCalculator.format_price taxed_sell_profit_after_procs} [max: #{@cli.green PriceCalculator.format_price(max_taxed_sell_profit_after_procs)}]
      #{padstr("multiply initial investment by")}#{formatted_roi}
  "

      { recipe_info: information, gain: max_taxed_sell_profit_after_procs }
    end
  end
end

# frozen_string_literal: true

module Utils
  class PriceCalculator
    def self.calculate_taxed_price(price, has_value_pack = true, fame_level  = 0)
      fame_levels = [1, 1.005, 1.01, 1.015]
      output_price = 0.65 * ((has_value_pack ? 0.3 : 0) + fame_levels[fame_level]) * price

      return output_price if output_price == Float::INFINITY
      return 0 unless output_price.is_a?(Numeric) && output_price.to_s.downcase != 'nan'
      output_price.floor
    end

    def self.format_price(price)
      return price.to_s.downcase if price == Float::INFINITY
      return 0 unless price.is_a?(Numeric) && price.to_s.downcase != 'nan'
      "¤#{price.floor.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}".to_s.downcase
    end

    def self.format_num(num)
      return num.to_s.downcase if num == Float::INFINITY
      return 0 unless num.is_a?(Numeric) && num.to_s.downcase != 'nan'
      num.floor.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse.to_s.downcase
    end
  end
end

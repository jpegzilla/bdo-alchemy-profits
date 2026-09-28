# frozen_string_literal: true

module Utils
  class ArrayUtils
    def self.make_permutations(list, n = 0, result = [], current = [], limit)
      if n == list.length && n == limit
        result.push current
      else
        list[n].each do |item|
          make_permutations list, n + 1, result, [*current, item], limit
        end
      end

      result
    end

    def self.deep_permute(input, limit)
      make_permutations input, limit
    end
  end

  def self.snake_sym(key)
    key.to_s.gsub(/(.)([A-Z])/, '\1_\2').downcase.to_sym
  end
end

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
end

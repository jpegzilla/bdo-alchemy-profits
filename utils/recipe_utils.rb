# frozen_string_literal: true

class CodexRecipe
  def initialize(id, name, ingredients, sell_price)

  end
end

# class used to define every ingredient returned from BDOCodex
class CodexIngredient
  attr_reader :id, :price, :sold_by_npc

  def initialize(id, name, price, sold_by_npc)

  end
end

# class used to define every ingredient as it will be used by
# the price calculation mechanisms
class Ingredient
  attr_reader :price_per_one, :count
end

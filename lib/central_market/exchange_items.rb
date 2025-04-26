# frozen_string_literal: true

module ExchangeItems
  EXCHANGE_ITEMS = {
    # magical lightstone crystal
    766108 => {
      # items you can exchange for this item. there are technically way more
      exchange_with: [766105, 766104, 766107, 766106],
      exchange_with_names: ['imperfect lightstone'],
      # how many of this item would you get if you exchanged it for the item ID above
      exchanging_grants: 6,
      exchange_with_npc: 'dalishain',
      count: Float::INFINITY,
      is_npc_item: true,
      name: 'Magical Lightstone Crystal',
      id: 766108,
    }
  }.freeze

  def get_exchange_item_info(item_to_exchange_id, item_to_exchange_for_id, price_of_exchange, quant_required)
    exchange_info = EXCHANGE_ITEMS[item_to_exchange_for_id]

    if exchange_info
      if exchange_info[:exchange_with].include? item_to_exchange_id
        # if a recipe requires 10 magical lightstone crystals, for example, and the exchange rate is
        # 1 imperfect lightstone for 6 crystals, you'll have to buy 2 imperfect lightstones to fill
        # the quant. since you can't buy a fraction of an item, we .ceil the number required.
        mult = (quant_required.to_f / exchange_info[:exchanging_grants].to_f).ceil
        return { **exchange_info, price: price_of_exchange * mult, must_exchange: mult }
      end
    end
  end
end

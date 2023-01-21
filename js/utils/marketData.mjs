const ROOT_URL = 'https://na-trade.naeu.playblackdesert.com/Trademarket'
const WORLD_MARKET_LIST = 'GetWorldMarketList'
// const WORLD_MARKET_PRICES = 'GetMarketPriceInfo'
const CONSUMABLE_CATEGORY = 35
const CONSUMABLE_SUBCATEGORIES = {
  OFFENSIVE: 1,
  DEFENSIVE: 2,
  FUNCTIONAL: 3,
  POTION: 5,
}

export const getConsumableMarketData = async (
  subCategory = CONSUMABLE_SUBCATEGORIES.OFFENSIVE
) => {
  if (!CONSUMABLE_SUBCATEGORIES.values.includes(subCategory)) {
    throw new TypeError(
      `subcategory must be one of: ${CONSUMABLE_SUBCATEGORIES.keys.join(', ')}`
    )
  }

  const list = await fetch(`${ROOT_URL}/${WORLD_MARKET_LIST}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'User-Agent': 'BlackDesert',
    },
    body: {
      keyType: 0,
      mainCategory: CONSUMABLE_CATEGORY,
      subCategory,
    },
  })

  console.log(list)
}

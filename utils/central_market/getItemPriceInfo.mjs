import axios from 'axios'
import chalk from 'chalk'
import fs from 'fs'
import path from 'path'

import env from './../../env.mjs'

import { NPC_ITEM_INDEX } from './../recipe/index.mjs'

const { RVT, ROOT_URL, MARKET_SUB_LIST, REQUEST_OPTS, MARKET_SELL_BUY_INFO } =
  env

const stream = fs.createWriteStream(path.join(process.cwd(), 'error.log'), {
  flags: 'a',
})

const url = `${ROOT_URL}${MARKET_SUB_LIST}`
const sellBuyUrl = `${ROOT_URL}${MARKET_SELL_BUY_INFO}`

export const getItemPriceInfo = async (itemId, isRecipeIngredient = false) => {
  if (isNaN(itemId)) {
    throw new TypeError(`must supply a numerical item id. got: ${itemId}`)
  }

  if (NPC_ITEM_INDEX?.[itemId]) return NPC_ITEM_INDEX[itemId]

  let response

  try {
    response = await axios.post(
      url,
      // usingCleint [sic] - watch out for this if pearl abyss fixes the typo
      `${RVT}&mainKey=${itemId}&usingCleint=0`,
      REQUEST_OPTS
    )
  } catch (e) {
    console.log(
      chalk.red(
        "\n\nif you're not messing with the code, you should never see this. please tell @jpegzilla getItemPriceInfo broke (that's me!)\n"
      )
    )

    stream.write(
      `=================== ERROR ===================
[${url}] ${itemId} (${new Date().toISOString()})
getItemPriceInfo broke, the market api may have changed. output:`
    )
    stream.write(JSON.stringify(e, null, 3))

    return false
  }

  if (!response?.data) {
    throw new Error(
      'there was an issue communicating with the black desert api. check your token / cookie.'
    )
  }

  const priceList = response.data?.detailList
  let detailedPriceList

  if (!priceList || priceList.length === 0) return false

  if (isRecipeIngredient) {
    const detailedPriceListResponse = await axios.post(
      sellBuyUrl,
      `mainKey=${itemId}&subKey=0&${RVT}&chooseKey=0&isUp=true&name=${priceList[0].name
        .split(' ')
        .join('+')}&keyType=0&mainCategory=${
        priceList[0].mainCategory
      }&subCategory=${priceList[0].subCategory}`,
      REQUEST_OPTS
    )

    if (!detailedPriceListResponse?.data) {
      throw new Error(
        'there was an issue communicating with the black desert api. check your token / cookie.'
      )
    }

    detailedPriceList = detailedPriceListResponse.data
  }

  let buyingPrice, buyingCount

  if (isRecipeIngredient) {
    const list = detailedPriceList.marketConditionList.sort(
      (a, b) => b.sellCount - a.sellCount
    )?.[0]

    if (list) {
      const { pricePerOne, sellCount } = list
      buyingPrice = pricePerOne
      buyingCount = sellCount
    }
  }

  if (!priceList[0]) {
    console.log(`item not found: ${itemId}`)

    return false
  }

  console.log({
    ...priceList[0],
    count: buyingCount || priceList[0].count,
    pricePerOne: buyingPrice || priceList[0].pricePerOne,
  })

  return {
    ...priceList[0],
    count: buyingCount || priceList[0].count,
    pricePerOne: buyingPrice || priceList[0].pricePerOne,
  }
}

import axios from 'axios'
import chalk from 'chalk'
import env from './../env.mjs'
import fs from 'fs'
import path from 'path'

import { NPC_ITEM_INDEX } from './npcItemList.mjs'

const {
  RVT,
  ROOT_URL,
  MARKET_SUB_LIST,
  HIDE_UNPROFITABLE_RECIPES,
  REQUEST_OPTS,
  MARKET_SELL_BUY_INFO,
  HIDE_OUT_OF_STOCK,
} = env

const url = `${ROOT_URL}${MARKET_SUB_LIST}`
const sellBuyUrl = `${ROOT_URL}${MARKET_SELL_BUY_INFO}`

const formatNum = num =>
  isNaN(num) ? false : Intl.NumberFormat('en-US').format(num)

const calculateTaxedProfit = (profit, valuePack = true, fameLevel = 1) => {
  // TODO: this calculation is wrong if profit is negative
  // which I guess doesn't really matter but still I'll fix it
  const fameLevels = [1, 1.005, 1.01, 1.015]
  const profitMinusTax = profit - profit * 0.65
  const outputProfit =
    profitMinusTax * (valuePack ? 1.3 : 1) * fameLevels[fameLevel]

  return Math.floor(outputProfit)
}

export const getItemPriceInfo = async (itemId, isRecipeIngredient = false) => {
  if (isNaN(itemId)) {
    throw new TypeError('must supply a numerical item id.')
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
getItemPriceInfo broke, the market api may have changed. output:
    ${JSON.stringify(e, null, 3)}

    `
    )

    return false
  }

  if (!response?.data) {
    throw new Error(
      'there was an issue communicating with the black desert api. check your token / cookie.'
    )
  }

  const priceList = response.data.detailList
  let detailedPriceList

  if (priceList.length === 0) return false

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

  return {
    ...priceList[0],
    count: buyingCount || priceList[0].count,
    pricePerOne: buyingPrice || priceList[0].pricePerOne,
  }
}

export const getAllRecipePrices = async (
  itemDataList,
  getIngredientCache,
  updateIngredientCache
) => {
  console.log()

  const stream = fs.createWriteStream(path.join(process.cwd(), 'error.log'), {
    flags: 'a',
  })

  const mappedRecipePrices = []
  const outOfStockItems = []
  try {
    for (const itemWithRecipe of itemDataList) {
      const {
        recipeList,
        item: itemName,
        price,
        id,
        totalInStock,
        totalTradeCount,
      } = itemWithRecipe
      const potentialRecipes = []

      process.stdout.cursorTo(0)
      process.stdout.clearLine()
      process.stdout.write(
        `  I'll ask a ${chalk.cyan(
          'merchant'
        )} about the price of ingredients for ${chalk.yellow(
          `[${itemName.toLowerCase()}]`
        )}!`
      )

      // find the cheapest recipe in a potion's recipe list
      // if (recipeList.length === 0) {
      //   console.log(`RECIPE LIST EMPTY FOR ${itemName}`)
      // }
      for (const recipe of recipeList) {
        const potentialRecipe = []

        for (const { quant, id } of recipe) {
          if (getIngredientCache(id)) {
            potentialRecipe.push({
              ...getIngredientCache(id),
              quant,
            })

            continue
          }
          let itemPriceInfo

          try {
            itemPriceInfo = await getItemPriceInfo(id, true)
          } catch (e) {
            console.log(e)
          }

          if (!itemPriceInfo) continue
          if (itemPriceInfo.count === 0 && Math.random() > 0.5)
            outOfStockItems.push(itemPriceInfo.name.toLowerCase())

          updateIngredientCache(id, itemPriceInfo)

          potentialRecipe.push({
            ...itemPriceInfo,
            quant,
          })
        }

        if (potentialRecipe.length !== recipe.length) continue

        potentialRecipes.push(potentialRecipe)
      }

      const mapper = item => item.pricePerOne * item.quant
      const sum = (a, b) => a + b

      const recipeToSave = potentialRecipes
        .sort((a, b) => {
          const priceA = a.map(mapper).reduce(sum, [])
          const priceB = b.map(mapper).reduce(sum, [])

          return priceA - priceB
        })?.[0]
        ?.map(item => {
          const totalPrice = item.pricePerOne * item.quant

          if (item.count === 0 && outOfStockItems.length === 0)
            outOfStockItems.push(item.name.toLowerCase())

          return {
            ...item,
            totalPrice,
            stock: item.count,
          }
        })

      if (!recipeToSave?.length) continue

      const totalRecipePrice = recipeToSave.reduce(
        (p, c) => p + c.totalPrice,
        0
      )
      const totalIngredientStock = recipeToSave
        .filter(r => !r?.isNPCItem)
        .reduce((p, c) => p + c.count, 0)

      const anyIngredientOut = recipeToSave
        .filter(r => !r?.isNPCItem)
        .some(r => r.count === 0 || r.count < r.quant)
      const profit = price - totalRecipePrice

      if (HIDE_UNPROFITABLE_RECIPES && profit < 0) continue
      if (HIDE_OUT_OF_STOCK && (totalIngredientStock < 10 || anyIngredientOut))
        continue

      const maxPotionCount = recipeToSave
        .map(e => {
          return e.stock === Infinity ? Infinity : ~~(e.stock / e.quant)
        })
        .sort((a, b) => a - b)[0]

      let stockCount = []
      for (const item of recipeToSave) {
        const maxPotionAmount =
          maxPotionCount === Infinity
            ? Infinity
            : item.stock === Infinity
            ? ~~(maxPotionCount / item.quant)
            : maxPotionCount * item.quant

        const price = item?.minPrice || item?.pricePerOne || 'unknown'

        if (maxPotionAmount * price < 0) continue

        const formattedPrice = chalk.yellow(formatNum(price))
        const formattedMaxPrice = chalk.yellow(
          formatNum(maxPotionAmount * price)
        )
        const formattedPotionAmount = chalk.yellow(formatNum(item.quant))
        const formattedMaxPotionAmount = chalk.yellow(
          formatNum(maxPotionAmount)
        )
        const formattedStockCount = chalk.yellow(formatNum(item.count))

        const formattedNPCInformation = item.isNPCItem
          ? chalk.yellow(` (sold by ${item.npcType} npcs)`)
          : ''

        stockCount.push(
          `${formattedPotionAmount} [max: ${formattedMaxPotionAmount}] ${chalk.yellow(
            `${item.name.toLowerCase()}: ${formattedStockCount}`
          )} in stock${formattedNPCInformation}. price: ${formattedPrice} [max: ${formattedMaxPrice}] silver`
        )
      }

      const information = `    ${chalk.yellow(
        `[${id}] [${itemName.toLowerCase()}]`
      )}

    market price of completed item: ${chalk.yellow(formatNum(price))} silver
    market stock of completed item: ${chalk.yellow(formatNum(totalInStock))}
    ${
      totalTradeCount
        ? `total trades of completed item: ${chalk.yellow(
            formatNum(totalTradeCount)
          )}`
        : ''
    }
    max amount you can create: ${chalk.yellow(formatNum(maxPotionCount))}
    cost of ingredients: ${chalk.yellow(formatNum(totalRecipePrice))} silver
    total max cost of ingredients: ${chalk.yellow(
      formatNum(totalRecipePrice * maxPotionCount)
    )} silver
    total ingredients in stock: ${chalk.yellow(formatNum(totalIngredientStock))}
\t${stockCount.join('\n\t')}
    total raw profit: ${`${chalk[profit <= 0 ? 'red' : 'green'](
      formatNum(profit)
    )} [max: ${chalk[profit * maxPotionCount <= 0 ? 'red' : 'green'](
      formatNum(~~(profit * maxPotionCount))
    )}]`} silver
    total taxed profit: ${`${chalk[
      calculateTaxedProfit(profit) <= 0 ? 'red' : 'green'
    ](formatNum(~~calculateTaxedProfit(profit)))} [max: ${chalk[
      calculateTaxedProfit(profit) * maxPotionCount <= 0 ? 'red' : 'green'
    ](formatNum(~~(calculateTaxedProfit(profit) * maxPotionCount)))}]`} silver
  `

      mappedRecipePrices.push({
        itemName,
        price,
        id,
        information,
        profit,
        maxTaxedProfit: ~~(calculateTaxedProfit(profit) * maxPotionCount),
        taxedProfit: calculateTaxedProfit(profit),
        recipe: {
          items: recipeToSave,
          totalPrice: totalRecipePrice,
        },
      })
    }
  } catch (e) {
    console.log(e)
    console.log(
      chalk.red(
        "\n\nif you're not messing with the code, you should never see this. please tell @jpegzilla getAllRecipePrices broke (that's me!)\n"
      )
    )

    stream.write(
      `=================== ERROR ===================
[${url}] ${id}, ${itemName} (${new Date().toISOString()})
getItemPriceInfo broke, the market api may have changed. output:
    ${JSON.stringify(e, null, 3)}

    `
    )
  }

  stream.end()

  return [
    mappedRecipePrices.sort((a, b) => a.maxTaxedProfit - b.maxTaxedProfit),
    outOfStockItems,
  ]
}

import axios from 'axios'
import env from './../env.json' assert { type: 'json' }
import chalk from 'chalk'

import { getItemCodexData } from './itemData.mjs'

const { RVT, COOKIE, BATCH_SIZE = Infinity, HIDE_UNPROFITABLE_RECIPES } = env

if (!RVT || !COOKIE) {
  throw new Error(
    chalk.red(
      'request verification token and cookie must both be defined in env.json. read the readme.md file!'
    )
  )
}

const ROOT_URL = 'https://na-trade.naeu.playblackdesert.com/Home'
const WORLD_MARKET_LIST = '/GetWorldMarketList'
const MARKET_SUB_LIST = '/GetWorldMarketSubList'
const CONSUMABLE_CATEGORY = 35
const CONSUMABLE_SUBCATEGORIES = {
  offensive: 1,
  defensive: 2,
  functional: 3,
  potion: 5,
}

const START = 0

const formatNum = num => Intl.NumberFormat('en-US').format(num)

export const getConsumableMarketData = async (subcategory = 'offensive') => {
  if (!CONSUMABLE_SUBCATEGORIES.keys.includes(subcategory)) {
    throw new TypeError(
      `subcategory must be one of: ${CONSUMABLE_SUBCATEGORIES.keys.join(', ')}`
    )
  }

  const url = `${ROOT_URL}${WORLD_MARKET_LIST}`

  const response = await axios.post(
    url,
    `${RVT}&mainCategory=${CONSUMABLE_CATEGORY}&subcategory=${CONSUMABLE_SUBCATEGORIES[subcategory]}`,
    {
      method: 'post',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36',
        Cookie: COOKIE,
      },
    }
  )

  if (!response || !response?.data) {
    throw new Error(
      'there was an issue communicating with the black desert api. check your token / cookie.'
    )
  }

  const data = response.data?.marketList

  // descending - most expensive to least
  const sortedData = data
    .sort((a, b) => b.minPrice - a.minPrice)
    .map(item => ({
      ...item,
      minPrice: formatNum(item.minPrice),
      sumCount: formatNum(item.sumCount),
    }))

  const amount = BATCH_SIZE || sortedData.length

  console.log(
    `\nI'll look for a maximum of ${chalk.cyan(amount)} consumable${
      amount === 0 || amount > 1 ? 's' : ''
    } in the ${chalk.cyan(subcategory)} subcategory!`
  )

  const itemDataList = await getItemCodexData(
    sortedData.slice(START, START + BATCH_SIZE || Infinity)
  )
  const mappedRecipePrices = []
  const outOfStockItems = []

  console.log()

  for (const itemWithRecipe of itemDataList) {
    const { recipeList, item: itemName, price, id } = itemWithRecipe
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
    for (const recipe of recipeList) {
      const potentialRecipe = []

      for (const { quant, id } of recipe) {
        const itemPriceInfo = await getItemPriceInfo(id)

        if (!itemPriceInfo) continue
        if (itemPriceInfo.count === 0 && Math.random() > 0.5)
          outOfStockItems.push(itemPriceInfo.name.toLowerCase())

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
        const priceA = a.map(mapper).reduce(sum)
        const priceB = b.map(mapper).reduce(sum)

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

    const totalRecipePrice = recipeToSave.reduce((p, c) => p + c.totalPrice, 0)
    const totalIngredientStock = recipeToSave.reduce((p, c) => p + c.count, 0)
    const anyIngredientOut = recipeToSave.some(r => r.count === 0)
    const profit = price.replaceAll(',', '') - totalRecipePrice

    if (HIDE_UNPROFITABLE_RECIPES && profit < 0) continue
    if (totalIngredientStock < 10 || anyIngredientOut) continue

    const stockCount = recipeToSave
      .map(
        e =>
          `    ${e.name.toLowerCase()}: ${chalk.yellow(
            formatNum(e.count)
          )} in stock`
      )
      .join('\n')

    const information = `${chalk.yellow(
      `  [${id}] [${itemName.toLowerCase()}]`
    )}

  market price of completed item: ${chalk.yellow(price)} silver
  cost of ingredients on the market: ${chalk.yellow(
    formatNum(totalRecipePrice)
  )} silver
  total ingredients in stock: ${chalk.yellow(formatNum(totalIngredientStock))}
${stockCount}
  total raw profit: ${
    profit < 0 ? chalk.red(formatNum(profit)) : chalk.green(formatNum(profit))
  } silver
`

    mappedRecipePrices.push({
      itemName,
      price,
      id,
      information,
      profit,
      recipe: {
        items: recipeToSave,
        totalPrice: totalRecipePrice,
      },
    })
  }

  const anyProfitsNegative = mappedRecipePrices.some(e => e.profit < 0)

  process.stdout.cursorTo(0)
  process.stdout.clearLine()
  console.log(
    `  alright, I found all the latest ${chalk.yellow('price information')}!`
  )

  // console.dir(mappedRecipePrices, { depth: null })

  if (mappedRecipePrices.length === 0 || HIDE_UNPROFITABLE_RECIPES) {
    const finalOutOfStockItems = [...new Set(outOfStockItems)]

    console.log(
      `\nit's not practical for us to buy those ingredients...come on, let's go ${chalk.yellow(
        'gathering together! ♫'
      )}\n`
    )
    console.log(
      `maybe we'll find some ${chalk.yellow(`[${finalOutOfStockItems[0]}]`)}${
        finalOutOfStockItems[1]
          ? ` or ${chalk.yellow(`[${finalOutOfStockItems[1]}]!`)}`
          : '!'
      }`
    )
    console.log()
  } else {
    console.log(
      `\nlooks like it's time to make some ${chalk.yellow(
        'potions!'
      )} let's pick one!`
    )

    if (anyProfitsNegative) {
      console.log(
        `\n♫ even if we don't make much money, it's still fun to do this ${chalk.yellow(
          'together~'
        )}`
      )
    }

    console.log()
    console.log(mappedRecipePrices.map(e => e.information).join('\n'))
  }

  return
}

export const getItemPriceInfo = async itemId => {
  if (isNaN(itemId)) {
    throw new TypeError('must supply a numerical item id.')
  }

  const url = `${ROOT_URL}${MARKET_SUB_LIST}`

  const response = await axios.post(
    url,
    // usingCleint [sic] - watch out for this if pearl abyss fixes the typo
    `${RVT}&mainKey=${itemId}&usingCleint=0`,
    {
      method: 'post',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36',
        Cookie: COOKIE,
      },
    }
  )

  if (!response || !response?.data) {
    throw new Error(
      'there was an issue communicating with the black desert api. check your token / cookie.'
    )
  }

  const priceList = response.data.detailList

  return priceList[0]
}

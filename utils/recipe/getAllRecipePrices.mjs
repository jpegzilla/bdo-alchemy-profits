import chalk from 'chalk'
import env from './../../env.mjs'
import fs from 'fs'
import path from 'path'

import { getItemPriceInfo } from './../centralMarket/getItemPriceInfo.mjs'

const { HIDE_UNPROFITABLE_RECIPES, HIDE_OUT_OF_STOCK } = env

const stream = fs.createWriteStream(path.join(process.cwd(), 'error.log'), {
  flags: 'a',
})

const formatNum = num =>
  isNaN(num) ? false : Intl.NumberFormat('en-US').format(num)

const calculateTaxedPrice = (price, valuePack = true, fameLevel = 1) => {
  const fameLevels = [1, 1.005, 1.01, 1.015]
  const outputPrice =
    0.65 * ((valuePack ? 0.3 : 0) + fameLevels[fameLevel]) * price

  return Math.floor(outputPrice)
}

export const getAllRecipePrices = async (
  itemDataList,
  getIngredientCache,
  updateIngredientCache,
  subcategory
) => {
  console.log()

  const mappedRecipePrices = []
  const outOfStockItems = []
  try {
    for (const itemWithRecipe of itemDataList) {
      const {
        recipeList,
        item: itemName,
        price: itemMarketPrice,
        id,
        totalInStock,
        totalTradeCount,
        mainCategory,
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
      for (const recipe of recipeList) {
        const potentialRecipe = []

        for (const { quant, id: ingredientId } of recipe) {
          if (getIngredientCache(ingredientId)) {
            potentialRecipe.push({
              ...getIngredientCache(ingredientId),
              quant,
            })

            continue
          }
          let itemPriceInfo

          try {
            itemPriceInfo = await getItemPriceInfo(ingredientId, true)
          } catch (e) {
            stream.write(JSON.stringify(e, null, 3))
          }

          if (!itemPriceInfo) continue
          if (itemPriceInfo.count === 0 && Math.random() > 0.5)
            outOfStockItems.push(itemPriceInfo.name.toLowerCase())

          updateIngredientCache(ingredientId, itemPriceInfo)

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

      let AVERAGE_PROCS = 1
      if ([25, 35].includes(mainCategory)) {
        if (
          !/oil of|draught|\[mix\]|\[party\]|immortal\:|perfume|indignation/.test(
            itemName.toLowerCase()
          )
        ) {
          AVERAGE_PROCS = 2
        }

        if (
          subcategory === 'reagent' ||
          /reagent/.test(itemName.toLowerCase())
        ) {
          AVERAGE_PROCS = 3
        }
      }

      const recipeToSave = potentialRecipes
        .filter(recipe => {
          return recipe.every(item => item.count > 0)
        })
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

      const totalOneIngredientsCost = Math.floor(
        recipeToSave.reduce((p, c) => p + c.totalPrice, 0) / AVERAGE_PROCS
      )
      const totalIngredientStock = recipeToSave
        .filter(r => !r?.isNPCItem)
        .reduce((p, c) => p + c.count, 0)

      const anyIngredientOut = recipeToSave
        .filter(r => !r?.isNPCItem)
        .some(r => r.count === 0 || r.count < r.quant)
      const profit = (itemMarketPrice - totalOneIngredientsCost) * AVERAGE_PROCS

      // console.log({
      //   profit,
      //   AVERAGE_PROCS,
      //   totalOneIngredientsCost,
      //   itemWithRecipe,
      // })

      if (HIDE_UNPROFITABLE_RECIPES && profit < 0) continue
      if (HIDE_OUT_OF_STOCK && (totalIngredientStock < 10 || anyIngredientOut))
        continue

      const maxPotionCount = recipeToSave
        .map(e => {
          return e.stock === Infinity ? Infinity : ~~(e.stock / e.quant)
        })
        .sort((a, b) => a - b)[0]

      const totalMaxIngredientCost = totalOneIngredientsCost * maxPotionCount

      let stockCount = []
      for (const item of recipeToSave) {
        const maxPotionAmount =
          maxPotionCount === Infinity
            ? Infinity
            : item.stock === Infinity
            ? ~~(maxPotionCount / item.quant)
            : maxPotionCount * item.quant

        const itemMarketPrice = item?.minPrice || item?.pricePerOne || 0

        if (maxPotionAmount * itemMarketPrice < 0) continue

        const formattedPrice = chalk.yellow(formatNum(itemMarketPrice))
        const formattedMaxPrice = chalk.yellow(
          formatNum(maxPotionAmount * itemMarketPrice)
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

    market price of completed item: ${chalk.yellow(
      formatNum(itemMarketPrice)
    )} silver
    market stock of completed item: ${chalk.yellow(formatNum(totalInStock))}
    ${
      totalTradeCount
        ? `total trades of completed item: ${chalk.yellow(
            formatNum(totalTradeCount)
          )}`
        : ''
    }
    max amount you can create: ${chalk.yellow(formatNum(maxPotionCount))}
    cost of ingredients: ${chalk.yellow(
      formatNum(totalOneIngredientsCost)
    )} silver (accounting for average ${AVERAGE_PROCS} / craft)
    total max cost of ingredients: ${chalk.yellow(
      formatNum(totalMaxIngredientCost)
    )} silver (accounting for average ${AVERAGE_PROCS} / craft)
    total ingredients in stock: ${chalk.yellow(formatNum(totalIngredientStock))}
\t${stockCount.join('\n\t')}
    total income for one item before cost subtraction: ${chalk.yellow(
      formatNum(itemMarketPrice * AVERAGE_PROCS)
    )}
    total income for max items before cost subtraction: ${chalk.yellow(
      formatNum(itemMarketPrice * AVERAGE_PROCS * maxPotionCount)
    )}
    total untaxed profit: ${`${chalk[profit <= 0 ? 'red' : 'green'](
      formatNum(profit)
    )} [max: ${chalk[profit * maxPotionCount <= 0 ? 'red' : 'green'](
      formatNum(profit * maxPotionCount)
    )}]`} silver
    total taxed profit: ${`${chalk[
      calculateTaxedPrice(profit) <= 0 ? 'red' : 'green'
    ](formatNum(calculateTaxedPrice(profit)))} [max: ${chalk[
      calculateTaxedPrice(profit * maxPotionCount) <= 0 ? 'red' : 'green'
    ](formatNum(calculateTaxedPrice(profit * maxPotionCount)))}]`} silver
  `

      mappedRecipePrices.push({
        itemName,
        price: itemMarketPrice,
        id,
        information,
        profit,
        maxTaxedProfit:
          calculateTaxedPrice(itemMarketPrice * maxPotionCount) -
          totalMaxIngredientCost,
        taxedProfit:
          calculateTaxedPrice(itemMarketPrice) - totalOneIngredientsCost,
        recipe: {
          items: recipeToSave,
          totalPrice: totalOneIngredientsCost,
        },
      })
    }
  } catch (e) {
    console.log(
      chalk.red(
        "\n\nif you're not messing with the code, you should never see this. please tell @jpegzilla getAllRecipePrices broke (that's me!)\n"
      )
    )

    console.log(e)

    stream.write(
      `=================== ERROR ===================
(${new Date().toISOString()})
getItemPriceInfo broke, the market api may have changed. output:

${e.message}`
    )
  }

  stream.end()

  return [
    mappedRecipePrices.sort((a, b) => a.maxTaxedProfit - b.maxTaxedProfit),
    outOfStockItems,
  ]
}

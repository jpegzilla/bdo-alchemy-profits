import chalk from 'chalk'
import fs from 'fs'
import path from 'path'

import { searchCodexForRecipes } from './searchCodex.mjs'

const ROOT_URL = 'https://bdocodex.com/us/item/'

export const getItemCodexData = async itemIdList => {
  const stream = fs.createWriteStream(path.join(process.cwd(), 'error.log'), {
    flags: 'a',
  })

  console.log(
    `\nI'm getting the ${chalk.cyan(
      'recipe book.'
    )} hold on! I like to take my time~!`
  )

  const recipes = []

  for (const {
    mainKey: itemId,
    name,
    minPrice,
    totalTradeCount,
    count,
    sumCount,
    grade,
    mainCategory,
  } of itemIdList) {
    if (!itemId || isNaN(itemId))
      throw new TypeError('itemId must be a number.')

    // if (name.toLowerCase() !== 'gold ingot') {
    //   continue
    // }
    // if (name.toLowerCase() !== 'han combined magic crystal - gervish') {
    //   continue
    // }
    // if (name.toLowerCase() !== "clown's blood") {
    //   continue
    // }
    // if (name !== 'Elixir of Wind') continue

    let allRecipesForPotion = []
    const url = `${ROOT_URL}${itemId}`

    try {
      allRecipesForPotion = await searchCodexForRecipes(
        itemId,
        name,
        null,
        grade,
        mainCategory
      )

      if (!allRecipesForPotion.length && mainCategory !== 80)
        allRecipesForPotion = await searchCodexForRecipes(
          itemId,
          name,
          false,
          grade,
          mainCategory
        )

      allRecipesForPotion = allRecipesForPotion.map(e => e[2])
    } catch (e) {
      console.log(
        chalk.red(
          "\n\nif you're not messing with the code, you should never see this. please tell @jpegzilla getItemCodexData broke (that's me!)\n"
        )
      )

      stream.write(
        `=================== ERROR ===================
      [${url}] ${itemId}, ${name} (${new Date().toISOString()})
      the bdocodex parser thing has broken. output: ${JSON.stringify(
        e,
        Object.getOwnPropertyNames(e),
        3
      )}`
      )

      continue
    }

    process.stdout.cursorTo(0)
    process.stdout.clearLine()
    process.stdout.write(
      `  let's read the recipe for ${chalk.yellow(
        `[${name.toLowerCase()}]`
      )}. hmm...`
    )

    recipes.push({
      item: name,
      recipeList: allRecipesForPotion, // .filter(e => e.length > 1),
      price: minPrice,
      id: itemId,
      totalTradeCount: isNaN(totalTradeCount)
        ? 'not available'
        : totalTradeCount,
      totalInStock: isNaN(+count || +sumCount)
        ? 'not available'
        : +count || +sumCount,
      mainCategory,
    })
  }
  stream.end()

  process.stdout.cursorTo(0)
  process.stdout.clearLine()
  console.log(
    `  ♫ that's all the recipes! looks like there are ${chalk.cyan(
      recipes.length
    )} of them in total. let's see how much it costs to make these!`
  )

  return recipes
}

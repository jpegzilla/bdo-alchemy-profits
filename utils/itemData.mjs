import axios from 'axios'
import chalk from 'chalk'
import fs from 'fs'
import path from 'path'
import jsdom from 'jsdom'

const { JSDOM } = jsdom
const DOMParser = new JSDOM().window.DOMParser

const ROOT_URL = 'https://bdocodex.com/us/item/'
const BDOCODEX_QUERY_DATA_KEY = 'aaData'

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
  } of itemIdList) {
    if (!itemId || isNaN(itemId))
      throw new TypeError('itemId must be a number.')

    // if (name.toLowerCase() !== 'gold ingot') {
    //   continue
    // }

    let allRecipesForPotion = []

    const url = `${ROOT_URL}${itemId}`
    const RECIPE_DIRECT_URL = `https://bdocodex.com/query.php?a=recipes&type=product&item_id=${itemId}&l=us`
    const MRECIPE_DIRECT_URL = `https://bdocodex.com/query.php?a=mrecipes&type=product&item_id=${itemId}&l=us`
    const RECIPE_COLUMNS = [
      'id',
      'icon',
      'title',
      'type',
      'skill level',
      'exp',
      'materials',
      'products',
      'matgroups',
    ]

    try {
      // TODO: there MUST be a better way to determine which recipe to use, rather than just trying them both.
      const searchForRecipes = async (
        recipeLinks = [MRECIPE_DIRECT_URL, RECIPE_DIRECT_URL]
      ) => {
        let itemWithIngredients = await axios.get(recipeLinks[0])

        if (!itemWithIngredients?.data) {
          itemWithIngredients = await axios.get(recipeLinks[1])
        }

        return itemWithIngredients.data[BDOCODEX_QUERY_DATA_KEY].map(arr =>
          arr
            .filter((_, i) => !!RECIPE_COLUMNS[i])
            .map((e, i) => {
              const elem = new DOMParser().parseFromString(e, 'text/html').body
                .textContent
              const category = RECIPE_COLUMNS[i]

              if (['materials', 'products'].includes(category)) {
                const quant = [...elem.matchAll(/\](\d+)/gi)].map(e => +e[1])
                const ids = [
                  ...elem.matchAll(/\/0*([1-9][0-9]*)\D?(?=\d?.webp)/gi),
                ].map(e => +e[1])

                return {
                  element: quant
                    .map((e, i) => ({ quant: e, id: ids[i] }))
                    .flat(),
                  category: category,
                }
              }

              if (category === 'title') {
                return { element: elem.toLowerCase(), category }
              }

              return { element: elem, category }
            })
            .filter(e =>
              ['id', 'title', 'materials', 'products', 'matgroups'].includes(
                e.category
              )
            )
            .map(e => e.element)
        )
          .filter(e => e[1].toLowerCase() === name.toLowerCase())
          .filter(e => e[3].length === 1)
      }

      allRecipesForPotion = await searchForRecipes()
      if (!allRecipesForPotion.length)
        allRecipesForPotion = await searchForRecipes([
          RECIPE_DIRECT_URL,
          MRECIPE_DIRECT_URL,
        ])

      const allRecipeSubstitutions = allRecipesForPotion.map((e, i) => [
        e[2],
        allRecipesForPotion.map(e => e.at(-1))[i],
      ])

      // TODO: FINISH THIS
      // console.log(allRecipeSubstitutions)
      // matgroups is an array structured like
      // [itemid, substituteid, substituteid, itemid, substituteid, substituteid, etc...]
      // if (category === 'matgroups') {
      //   console.log(JSON.parse(e))
      // }

      allRecipesForPotion = allRecipesForPotion.map(e => e[2])
    } catch (e) {
      console.log(e)
      console.log(
        chalk.red(
          "\n\nif you're not messing with the code, you should never see this. please tell @jpegzilla getItemCodexData broke (that's me!)\n"
        )
      )

      stream.write(
        `=================== ERROR ===================
      [${url}] ${itemId}, ${name} (${new Date().toISOString()})
      the bdocodex parser thing has broken. output:
            ${JSON.stringify(e, null, 3)}

            `
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

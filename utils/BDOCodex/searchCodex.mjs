import jsdom from 'jsdom'
import axios from 'axios'
import fs from 'fs'
import path from 'path'

import env from './../../env.mjs'

const { AXIOS_HEADERS, RECIPE_FILE_NAME } = env
const { JSDOM } = jsdom
const DOMParser = new JSDOM().window.DOMParser

const BDOCODEX_QUERY_DATA_KEY = 'aaData'
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

const ensureFile = filename => {
  fs.open(filename, 'r', err => {
    if (err) {
      fs.writeFile(filename, '', err => {
        if (err) {
          console.log(err)
        }
      })
    }
  })
}

ensureFile(RECIPE_FILE_NAME)

// TODO: there MUST be a better way to determine which recipe to use, rather than just trying them both.
export const searchCodexForRecipes = async (
  itemId,
  name,
  mRecipesFirst = true,
  grade = 1,
  mainCategory
) => {
  // try to pull recipe from cache first
  const itemIndex = `${itemId} ${name}`
  const fileAsString = fs.readFileSync(RECIPE_FILE_NAME).toString()
  const parsedJSON = JSON.parse(fileAsString || '{}')
  const potentialCachedRecipes = parsedJSON[itemIndex]

  if (potentialCachedRecipes) {
    return potentialCachedRecipes.filter(
      e => e[1].toLowerCase() === name.toLowerCase()
    )
  }

  const RECIPE_DIRECT_URL = `https://bdocodex.com/query.php?a=recipes&type=product&item_id=${itemId}&l=us`
  const MRECIPE_DIRECT_URL = `https://bdocodex.com/query.php?a=mrecipes&type=product&item_id=${itemId}&l=us`
  const HOUSERECIPE_DIRECT_URL = `https://bdocodex.com/query.php?a=designs&type=product&item_id=${itemId}&l=us`
  let recipeLinks = [MRECIPE_DIRECT_URL, RECIPE_DIRECT_URL]

  let itemWithIngredients
  if (mainCategory === 80) {
    itemWithIngredients = await axios.get(HOUSERECIPE_DIRECT_URL, {
      headers: AXIOS_HEADERS,
    })
  } else {
    if (!mRecipesFirst) recipeLinks = recipeLinks.reverse()

    if (!itemWithIngredients?.data) {
      itemWithIngredients = await axios.get(recipeLinks[0], {
        headers: AXIOS_HEADERS,
      })
    }

    if (!itemWithIngredients?.data) {
      itemWithIngredients = await axios.get(recipeLinks[1], {
        headers: AXIOS_HEADERS,
      })
    }
  }

  const allRecipesForPotion = itemWithIngredients.data[
    BDOCODEX_QUERY_DATA_KEY
  ].map(arr =>
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
            element: quant.map((e, i) => ({ quant: e, id: ids[i] })).flat(),
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

  // console.log(allRecipesForPotion)
  // const allRecipeSubstitutions = []
  // for (let i = 0; i < allRecipesForPotion.length; i++) {
  //   const recipe = allRecipesForPotion[i]
  //   const originalRecipe = recipe[2]
  //   const newRecipes = []
  //   const potentialSubs = allRecipesForPotion.map(e => e.at(-1))[i]
  //
  //   if (recipe[1].toLowerCase() !== "clown's blood") continue
  //
  //   const thing = [originalRecipe.map(e => e.id), potentialSubs]
  //
  //   for (const ingredient of originalRecipe) {
  //   }
  //
  //   console.log({ thing })
  // }
  //
  // // TODO: FINISH THIS
  // console.log(allRecipeSubstitutions)
  // // matgroups is an array structured like
  // // [itemid, substituteid, substituteid, itemid, substituteid, substituteid, etc...]
  //
  // const constructPermutations = () => {}

  // cache the recipe for later. if recipes change, we need to delete this file and re-run the scripy to generate a new cache. if a new recipe is added, it doesn't have to be deleted.
  const newRecipes = {
    ...parsedJSON,
    [itemIndex]: allRecipesForPotion,
  }
  const stringifiedRecipes = JSON.stringify(newRecipes, null, 3)
  fs.writeFileSync(RECIPE_FILE_NAME, stringifiedRecipes)

  return allRecipesForPotion.filter(
    e => e[1].toLowerCase() === name.toLowerCase()
  )
  // .filter(e => e[3].length === 1) // this was originally written to get rid of recipes that only have a CHANCE to produce what we want, and thus have more than one product
}

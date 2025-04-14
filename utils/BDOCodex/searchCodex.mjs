import jsdom from 'jsdom'
import axios from 'axios'
import fs from 'fs'
import path from 'path'

import { deepPermute } from './../arrayUtils.mjs'

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
  'total weight of materials',
  'products',
  'all ingredients',
]

const ensureFile = filename => {
  if (!fs.existsSync(filename)) {
    fs.writeFileSync(filename, '')
  }
}

ensureFile(RECIPE_FILE_NAME)

const fileAsString = fs.readFileSync(RECIPE_FILE_NAME).toString()
const parsedJSON = JSON.parse(fileAsString || '{}')

// TODO: there MUST be a better way to determine which recipe to use, rather than just trying them both.
export const searchCodexForRecipes = async (
  itemId,
  name,
  mRecipesFirst = true,
  grade = 1,
  mainCategory
) => {
  // if (name.toLowerCase() !== "clown's blood") return []
  // try to pull recipe from cache first
  const itemIndex = `${itemId} ${name}`
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

  // for a recipe length of 4, for example,
  // recipes are formatted like this in this object:
  // [itemID, substitute, itemID, substitute, itemID, substitute...]
  const recipeWithSubstitudeIDs = itemWithIngredients.data[
    BDOCODEX_QUERY_DATA_KEY
  ].map(
    arr => arr.filter((_, i) => i === 9).map(item => JSON.parse(item))[0]
  )[0]

  const allRecipesForPotion = itemWithIngredients.data[
    BDOCODEX_QUERY_DATA_KEY
  ].map(arr =>
    arr
      .filter((_, i) => !!RECIPE_COLUMNS[i])
      .map((e, i) => {
        const elem = new DOMParser().parseFromString(e, 'text/html').body
        const category = RECIPE_COLUMNS[i]

        if (['materials', 'products'].includes(category)) {
          const quants = [...elem.textContent.matchAll(/\](\d+)/gi)].map(
            e => +e[1]
          )

          const ids = [
            ...elem.innerHTML.matchAll(/\/item\/([1-9][0-9]*)\D/gi),
          ].map(e => +e[1])

          return {
            element: ids.map((e, i) => ({ id: e, quant: quants[i] })).flat(),
            category,
          }
        }

        if (category === 'title') {
          return { element: elem.textContent.toLowerCase(), category }
        }

        return { element: elem.textContent, category }
      })
      .filter(e =>
        ['id', 'title', 'materials', 'products'].includes(e.category)
      )
      .map(e => e.element)
  )

  const allRecipeSubstitutions = []
  for (let i = 0; i < allRecipesForPotion.length; i++) {
    const recipe = allRecipesForPotion[i]
    const originalRecipe = recipe[2]
    const originalIngredientIndices = originalRecipe.map(item =>
      recipeWithSubstitudeIDs.findIndex(id => id === item.id)
    )

    // slice from originalIngredientIndices 0 - i, i-i2, i2-i3, etc.
    const chunkedBySubstitutionGroups = []

    originalIngredientIndices.forEach((index, i, arr) => {
      const sliceFrom = Math.max(0, originalIngredientIndices[i])
      const sliceTo = originalIngredientIndices[i + 1]

      chunkedBySubstitutionGroups.push(
        recipeWithSubstitudeIDs.slice(sliceFrom, sliceTo ? sliceTo : Infinity)
      )
    })

    const originalRecipeLength = originalRecipe.length
    const permutatedChunks = deepPermute(
      chunkedBySubstitutionGroups,
      originalRecipeLength
    )

    permutatedChunks.forEach(idList => {
      const recipeWithNewItems = [...recipe]
      recipeWithNewItems[2] = [...recipe][2].map((recipe, i) => ({
        ...recipe,
        id: idList[i],
      }))
      allRecipeSubstitutions.push(recipeWithNewItems)
    })
  }

  // matgroups is an array structured like
  // [itemid, substituteid, substituteid, itemid, substituteid, substituteid, etc...]

  // cache the recipe for later. if recipes change, we need to delete this file and re-run the script to generate a new cache. if a new recipe is added, it doesn't have to be deleted.
  const newRecipes = {
    ...parsedJSON,
    [itemIndex]: allRecipeSubstitutions,
  }

  // const stringifiedRecipes = JSON.stringify(newRecipes)
  // fs.writeFileSync(RECIPE_FILE_NAME, stringifiedRecipes)

  return allRecipeSubstitutions.filter(
    e => e[1].toLowerCase() === name.toLowerCase()
  )
  // .filter(e => e[3].length === 1) // this was originally written to get rid of recipes that only have a CHANCE to produce what we want, and thus have more than one product
}

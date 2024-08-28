import axios from 'axios'
import env from './../../env.mjs'
import chalk from 'chalk'

import { aggregateCategoryData } from './getCategoryData.mjs'
import { getItemPriceInfo } from './getItemPriceInfo.mjs'
import { getItemCodexData } from './../BDOCodex/index.mjs'
import { getAllRecipePrices, logRecipeInfo } from './../recipe/index.mjs'

const {
  RVT,
  COOKIE,
  BATCH_SIZE = Infinity,
  HIDE_UNPROFITABLE_RECIPES,
  ROOT_URL,
  WORLD_MARKET_LIST,
  MARKET_SEARCH_LIST,
  REQUEST_OPTS,
  HIDE_OUT_OF_STOCK,
} = env

if (!RVT || !COOKIE) {
  throw new Error(
    chalk.red(
      'request verification token and cookie must both be defined in env.json. read the readme.md file!'
    )
  )
}

const CONSUMABLE_CATEGORY = 35
const CONSUMABLE_SUBCATEGORIES = {
  offensive: 1,
  defensive: 2,
  functional: 3,
  potion: 5,
  all: [1, 2, 3, 5],
}

const FURNITURE_CATEGORY = 80
const FURNITURE_SUBCATEGORIES = {
  all: [1, 2, 3, 4, 5, 6, 7, 8, 9],
}

const START = 0

const INGREDIENT_CACHE = {}

const retryFailedRequest = err => {
  if (err.status === 500 && err.config && !err.config.__isRetryRequest) {
    err.config.__isRetryRequest = true

    return axios(err.config)
  }

  throw err
}

axios.interceptors.response.use(undefined, retryFailedRequest)

const specialSubcategory = {
  furniture: false,
  consumable: false,
}
const url = `${ROOT_URL}${WORLD_MARKET_LIST}`
const searchURL = `${ROOT_URL}${MARKET_SEARCH_LIST}`

export const getConsumableMarketData = async (
  subcategory = 'offensive',
  allSubcategories = false
) => {
  if (subcategory === 'furniture') {
    specialSubcategory.furniture = true
  }
  if (
    ![
      'blood',
      'oil',
      'alchemy stone',
      'reagent',
      'black stone',
      'magic crystal',
      'metal and ore',
      'furniture',
    ].includes(subcategory)
  ) {
    specialSubcategory.consumable = true
  }

  if (
    !Object.keys(CONSUMABLE_SUBCATEGORIES).includes(subcategory) &&
    specialSubcategory.consumable === true
  ) {
    throw new TypeError(
      `subcategory must be one of: ${Object.keys(CONSUMABLE_SUBCATEGORIES).join(
        ', '
      )}`
    )
  }

  let aggregateResponse

  if (
    allSubcategories ||
    specialSubcategory.consumable ||
    specialSubcategory.furniture
  ) {
    aggregateResponse = await constructItemData(
      specialSubcategory,
      subcategory,
      allSubcategories
    )
  } else {
    const response = await axios.post(
      url,
      `${RVT}&mainCategory=${CONSUMABLE_CATEGORY}&subcategory=${CONSUMABLE_SUBCATEGORIES[subcategory]}`,
      REQUEST_OPTS
    )

    aggregateResponse = response.data?.marketList
  }

  // descending - most expensive to least
  const sortedData = aggregateResponse
    .sort(
      (a, b) => b?.minPrice || b?.pricePerOne - a?.minPrice || a?.pricePerOne
    )
    .map(item => {
      return {
        ...item,
        minPrice: isNaN(item?.pricePerOne) ? item?.minPrice : item?.pricePerOne,
        sumCount: isNaN(item?.sumCount) ? item?.count : item?.sumCount,
      }
    })

  const amount = BATCH_SIZE || sortedData.length

  console.log(
    `\nI'll look for a maximum of ${chalk.cyan(amount)} item${
      amount === 0 || amount > 1 ? 's' : ''
    } in the ${chalk.cyan(subcategory)} subcategory!`
  )

  const itemDataList = await getItemCodexData(
    sortedData.slice(START, START + BATCH_SIZE || Infinity)
  )

  const recipePrices = await getAllRecipePrices(
    itemDataList,
    id => INGREDIENT_CACHE[id] || false,
    (id, ingredient) => {
      INGREDIENT_CACHE[id] = ingredient
    }
  )

  const [mappedRecipePrices, outOfStockItems] = recipePrices

  const recipesToShow = mappedRecipePrices
    .filter(r =>
      r.recipe.items.every(i => (HIDE_OUT_OF_STOCK ? i.stock > 0 : true))
    )
    .filter(e =>
      HIDE_UNPROFITABLE_RECIPES && e.taxedProfit < 0 ? false : true
    )

  const anyProfitsNegative = mappedRecipePrices.some(e => e.taxedProfit < 0)
  // const allProfitsNegative = mappedRecipePrices.every(e => e.taxedProfit < 0)

  process.stdout.cursorTo(0)
  process.stdout.clearLine()
  console.log(
    `  alright, I found all the latest ${chalk.yellow('price information')}!`
  )

  const finalOutOfStockItems = [...new Set(outOfStockItems)]

  logRecipeInfo(
    !(HIDE_OUT_OF_STOCK && recipesToShow.length === 0) ||
      (HIDE_UNPROFITABLE_RECIPES && anyProfitsNegative),
    anyProfitsNegative,
    recipesToShow,
    finalOutOfStockItems
  )

  return
}

const constructItemData = async (
  specialSubcategory,
  subcategory,
  allSubcategories
) => {
  const {
    bloodResponse,
    oilResponse,
    reagentResponse,
    blackStoneResponse,
    alchemyStoneResponse,
    magicCrystalResponse,
    // metalAndOreResponse,
  } = await aggregateCategoryData(url, searchURL, subcategory, allSubcategories)

  let consumableResponse = {
    data: {
      marketList: [],
    },
  }

  let furnitureResponse = {
    data: {
      marketList: [],
    },
  }

  if (specialSubcategory.consumable === true) {
    for (const subCatId of CONSUMABLE_SUBCATEGORIES.all) {
      const response = await axios.post(
        url,
        `${RVT}&mainCategory=${CONSUMABLE_CATEGORY}&subcategory=${subCatId}`,
        REQUEST_OPTS
      )

      if (!response || !response?.data) {
        throw new Error(
          'there was an issue communicating with the black desert api. check your token / cookie. (consumable category)'
        )
      }

      const data = response.data?.marketList

      consumableResponse.data.marketList = [
        ...consumableResponse.data.marketList,
        ...data,
      ]
    }
  }

  if (specialSubcategory.furniture === true) {
    for (const subCatId of FURNITURE_SUBCATEGORIES.all) {
      const response = await axios.post(
        url,
        `${RVT}&mainCategory=${FURNITURE_CATEGORY}&subcategory=${subCatId}`,
        REQUEST_OPTS
      )

      if (!response || !response?.data) {
        throw new Error(
          'there was an issue communicating with the black desert api. check your token / cookie. (furniture category)'
        )
      }

      const data = response.data?.marketList

      furnitureResponse.data.marketList = [
        ...furnitureResponse.data.marketList,
        ...data,
      ]
    }
  }

  if (
    (!specialSubcategory.consumable && !consumableResponse?.data) ||
    (!specialSubcategory.furniture && !furnitureResponse?.data) ||
    (subcategory === 'blood' && !bloodResponse?.data) ||
    (subcategory === 'oil' && !oilResponse?.data) ||
    (subcategory === 'reagent' && !reagentResponse?.data) ||
    (subcategory === 'black stone' && !blackStoneResponse?.data) ||
    (subcategory === 'alchemy stone' && !alchemyStoneResponse?.data) ||
    (subcategory === 'magic crystal' && !magicCrystalResponse?.data)
    // ||
    // (subcategory === 'metal and ore' && !metalAndOreResponse?.data)
  ) {
    throw new Error(
      'there was an issue communicating with the black desert api. check your token / cookie. (blood / oil / black stone / reagent / alchemy stone / magic crystal response invalid)'
    )
  }

  const bloodData = []
  if (bloodResponse?.data)
    for (const blood of bloodResponse.data.list) {
      const data = await getItemPriceInfo(blood.mainKey)
      if (data.grade === 0) bloodData.push(data)
    }

  const reagentData = []
  if (reagentResponse?.data)
    for (const reagent of reagentResponse.data.list) {
      const data = await getItemPriceInfo(reagent.mainKey)
      reagentData.push(data)
    }

  const oilData = []
  if (oilResponse?.data)
    for (const oil of oilResponse.data.list) {
      const data = await getItemPriceInfo(oil.mainKey)
      if (data.grade === 0) oilData.push(data)
    }

  const intermediateConsumableData =
    consumableResponse?.data?.marketList.filter(i => i.grade <= 1) || []

  const intermediateFurnitureData =
    // furnitureResponse?.data?.marketList.filter(i => i.grade <= 1) || []
    furnitureResponse?.data?.marketList || []

  const intermediateBlackStoneData = blackStoneResponse?.data?.marketList || []

  const blackStoneData = []
  for (const blackStone of intermediateBlackStoneData) {
    const data = await getItemPriceInfo(blackStone.mainKey)
    blackStoneData.push(data)
  }

  const consumableData = []
  for (const consumable of intermediateConsumableData) {
    const data = await getItemPriceInfo(consumable.mainKey)
    consumableData.push(data)
  }

  const furnitureData = []
  for (const furniture of intermediateFurnitureData) {
    const data = await getItemPriceInfo(furniture.mainKey)
    furnitureData.push(data)
  }

  const alchemyStoneData = []
  if (alchemyStoneResponse?.data)
    for (const alchemyStone of alchemyStoneResponse.data.list.filter(i =>
      i.name.toLowerCase().includes('imperfect')
    )) {
      const data = await getItemPriceInfo(alchemyStone.mainKey)
      alchemyStoneData.push(data)
    }

  const magicCrystalData = []
  if (magicCrystalResponse?.data)
    for (const magicCrystal of magicCrystalResponse.data.list) {
      const data = await getItemPriceInfo(magicCrystal.mainKey)
      magicCrystalData.push(data)
    }

  // const metalAndOreData = []
  // if (metalAndOreResponse?.data)
  //   for (const metal of metalAndOreResponse.data.marketList) {
  //     const data = await getItemPriceInfo(metal.mainKey)
  //     metalAndOreData.push(data)
  //   }

  return [
    ...consumableData,
    ...oilData,
    ...bloodData,
    ...reagentData,
    ...alchemyStoneData,
    ...blackStoneData,
    ...magicCrystalData,
    // ...metalAndOreData,
    ...furnitureData,
  ]
}

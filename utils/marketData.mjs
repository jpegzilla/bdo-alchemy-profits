import axios from 'axios'
import env from './../env.mjs'
import chalk from 'chalk'

import { getItemCodexData } from './itemData.mjs'
import { getItemPriceInfo, getAllRecipePrices } from './itemPriceInfo.mjs'

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

let nonPotionSubCategory = false

export const getConsumableMarketData = async (
  subcategory = 'offensive',
  allSubcategories = false
) => {
  if (
    [
      'blood',
      'oil',
      'alchemy stone',
      'reagent',
      'black stone',
      'magic crystal',
    ].includes(subcategory)
  )
    nonPotionSubCategory = true

  if (
    !Object.keys(CONSUMABLE_SUBCATEGORIES).includes(subcategory) &&
    nonPotionSubCategory === false
  ) {
    throw new TypeError(
      `subcategory must be one of: ${Object.keys(CONSUMABLE_SUBCATEGORIES).join(
        ', '
      )}`
    )
  }

  const url = `${ROOT_URL}${WORLD_MARKET_LIST}`
  const searchURL = `${ROOT_URL}${MARKET_SEARCH_LIST}`
  let consumableResponse = {
    data: {
      marketList: [],
    },
  }

  let aggregateResponse

  const doIfCategoryMatches = async (subcat, cb) => {
    if (subcategory === subcat || allSubcategories) await cb()
  }

  if (allSubcategories || nonPotionSubCategory) {
    if (!nonPotionSubCategory) {
      for (const subCatId of CONSUMABLE_SUBCATEGORIES.all) {
        const response = await axios.post(
          url,
          `${RVT}&mainCategory=${CONSUMABLE_CATEGORY}&subcategory=${subCatId}`,
          REQUEST_OPTS
        )

        if (!response || !response?.data) {
          throw new Error(
            'there was an issue communicating with the black desert api. check your token / cookie. (all categories)'
          )
        }

        const data = response.data?.marketList

        consumableResponse.data.marketList = [
          ...consumableResponse.data.marketList,
          ...data,
        ]
      }
    }

    let blackStoneResponse = []
    await doIfCategoryMatches('black stone', async () => {
      blackStoneResponse = await axios.post(
        url,
        `${RVT}&mainCategory=30&subcategory=1`,
        REQUEST_OPTS
      )
    })

    let bloodResponse = []
    await doIfCategoryMatches('blood', async () => {
      bloodResponse = await axios.post(
        searchURL,
        `${RVT}&searchText='s+blood`,
        REQUEST_OPTS
      )
    })

    let reagentResponse = []
    await doIfCategoryMatches('reagent', async () => {
      reagentResponse = await axios.post(
        searchURL,
        `${RVT}&searchText=reagent`,
        REQUEST_OPTS
      )
    })

    let oilResponse = []
    await doIfCategoryMatches('oil', async () => {
      oilResponse = await axios.post(
        searchURL,
        `${RVT}&searchText=oil+of`,
        REQUEST_OPTS
      )
    })

    let alchemyStoneResponse = []
    await doIfCategoryMatches('alchemy stone', async () => {
      alchemyStoneResponse = await axios.post(
        searchURL,
        `${RVT}&searchText=alchemy+stone`,
        REQUEST_OPTS
      )
    })

    let magicCrystalResponse = []
    await doIfCategoryMatches('magic crystal', async () => {
      magicCrystalResponse = await axios.post(
        searchURL,
        `${RVT}&searchText=magic+crystal`,
        REQUEST_OPTS
      )
    })

    if (
      (!nonPotionSubCategory && !consumableResponse?.data) ||
      (subcategory === 'blood' && !bloodResponse?.data) ||
      (subcategory === 'oil' && !oilResponse?.data) ||
      (subcategory === 'reagent' && !reagentResponse?.data) ||
      (subcategory === 'black stone' && !blackStoneResponse?.data) ||
      (subcategory === 'alchemy stone' && !alchemyStoneResponse?.data) ||
      (subcategory === 'magic crystal' && !magicCrystalResponse?.data)
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
    const intermediateBlackStoneData =
      blackStoneResponse?.data?.marketList || []

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

    aggregateResponse = [
      ...consumableData,
      ...oilData,
      ...bloodData,
      ...reagentData,
      ...alchemyStoneData,
      ...blackStoneData,
      ...magicCrystalData,
    ]
  } else {
    const response = await axios.post(
      url,
      `${RVT}&mainCategory=${CONSUMABLE_CATEGORY}&subcategory=${CONSUMABLE_SUBCATEGORIES[subcategory]}`,
      REQUEST_OPTS
    )

    const consumableData = response.data?.marketList

    aggregateResponse = consumableData
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

  const recipesToShow = mappedRecipePrices.filter(r =>
    r.recipe.items.every(i => (HIDE_OUT_OF_STOCK ? i.stock > 0 : true))
  )

  const anyProfitsNegative = mappedRecipePrices.some(e => e.taxedProfit < 0)
  const allProfitsNegative = mappedRecipePrices.every(e => e.taxedProfit < 0)

  process.stdout.cursorTo(0)
  process.stdout.clearLine()
  console.log(
    `  alright, I found all the latest ${chalk.yellow('price information')}!`
  )

  if (
    (HIDE_OUT_OF_STOCK && recipesToShow.length === 0) ||
    (HIDE_UNPROFITABLE_RECIPES && allProfitsNegative)
  ) {
    const finalOutOfStockItems = [...new Set(outOfStockItems)]

    console.log(
      `\nit's not practical for us to buy those ingredients...come on, let's go ${chalk.yellow(
        'gathering together! ♫'
      )}\n`
    )
    if (finalOutOfStockItems.length > 0)
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
      `\nlooks like it's time to do some ${chalk.yellow(
        'alchemy!'
      )} let's pick one!`
    )

    if (anyProfitsNegative) {
      console.log(
        "\n♫ even if we don't make much money, it's still fun to do this together~"
      )
    }

    console.log()
    console.log(recipesToShow.map(e => e.information).join('\n'))
  }

  return
}

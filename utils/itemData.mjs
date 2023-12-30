import puppeteer from 'puppeteer'
import axios from 'axios'
import chalk from 'chalk'
import fs from 'fs'
import env from './../env.mjs'
import path from 'path'
import jsdom from 'jsdom'

const { JSDOM } = jsdom
const DOMParser = new JSDOM().window.DOMParser

const { PUPPETEER_ARGS } = env
const ROOT_URL = 'https://bdocodex.com/us/item/'
const ROOT_MATGROUP_URL = 'https://bdocodex.com/us/materialgroup/'
const BDOCODEX_QUERY_DATA_KEY = 'aaData'

const MATGROUP_ITEM_CACHE = {}

const updateMgItemCache = (id, item) => (MATGROUP_ITEM_CACHE[id] = item)
const getCachedMgItem = id => MATGROUP_ITEM_CACHE?.[id]

// https://stackoverflow.com/a/65424198
const retryWrapper = (axios, { maxRetries }) => {
  let counter = 0

  axios.interceptors.response.use(null, ({ config }) => {
    if (counter < maxRetries) {
      counter++

      return new Promise(resolve => {
        resolve(axios(config))
      })
    }

    return Promise.reject(error)
  })
}

export const getItemCodexData = async (
  itemIdList,
  selector = '#MProductRecipeTable, #ProductRecipeTable'
) => {
  const stream = fs.createWriteStream(path.join(process.cwd(), 'error.log'), {
    flags: 'a',
  })

  console.log(
    `\nI'm getting the ${chalk.cyan(
      'recipe book.'
    )} hold on! I like to take my time~!`
  )

  const browser = await puppeteer.launch({
    headless: true,
    args: PUPPETEER_ARGS,
    ignoreHTTPSErrors: true,
    userDataDir: path.join(process.cwd(), 'puppeteer_cache'),
    executablePath: path.join(process.cwd(), 'chrome_bin/win/chrome.exe'),
  })

  const killBrowser = () => {
    if (browser && browser.process() != null) browser.process().kill('SIGINT')
  }

  // in the words of the great calliope mori
  // ごめん、失礼しますが死んでください
  process.on('exit', killBrowser)
  process.on('SIGINT', killBrowser)
  process.on('SIGUSR1', killBrowser)
  process.on('SIGUSR2', killBrowser)
  process.on('uncaughtException', killBrowser)

  const recipes = []

  console.log()

  for (const {
    useAltRecipe = false,
    mainKey: itemId,
    name,
    minPrice,
    totalTradeCount,
    count,
    sumCount,
  } of itemIdList) {
    if (!itemId || isNaN(itemId))
      throw new TypeError('itemId must be a number.')

    if (name.toLowerCase() !== "clown's blood") {
      continue
    }

    const url = `${ROOT_URL}${itemId}`
    const recipeDirectURL = `https://bdocodex.com/query.php?a=mrecipes&type=product&item_id=${itemId}&l=us`
    const RECIPE_COLUMNS = [
      'id',
      'icon',
      'title',
      'type',
      'skill level',
      'exp',
      'materials',
      'products',
      'prodarray',
    ]

    try {
      retryWrapper(axios, { maxRetries: 3 })
      const pageString = await axios.get(url)

      if (useAltRecipe) {
        const itemWithIngredients = await axios.get(recipeDirectURL)
        console.log(
          itemWithIngredients.data[BDOCODEX_QUERY_DATA_KEY].map(arr =>
            arr
              .filter((_, i) => !!RECIPE_COLUMNS[i])
              .map((e, i) => {
                const elem = new DOMParser().parseFromString(e, 'text/html')
                  .body.textContent

                return { element: elem, category: RECIPE_COLUMNS[i] }
              })
              .filter(e => e.category === 'prodarray')
              .map(e => JSON.parse(e.element))
          )
        )
      }

      if (!pageString.data.includes('ProductRecipeTable')) continue

      const page = await browser.newPage()
      await page.setRequestInterception(true)

      page.on('request', request => {
        if (
          (/twitch|doubleclick|track1|googlesyndication|rubicon|track1|analytics|aniview/.test(
            request.url()
          ) ||
            /image|stylesheet|font|video|webp|svg|ping/.test(
              request.resourceType()
            )) &&
          !request.isInterceptResolutionHandled()
        ) {
          request.respond({ status: 200, body: 'aborted' })
        } else request.continue()
      })

      await page.goto(url)

      // for debugging
      await page.exposeFunction('conlog', (...args) => console.log(...args))

      process.stdout.cursorTo(0)
      process.stdout.clearLine()
      process.stdout.write(
        `  let's read the recipe for ${chalk.yellow(
          `[${name.toLowerCase()} (#${itemId})]`
        )}. hmm...`
      )

      let element
      try {
        element = await page.waitForSelector(selector, { timeout: 5000 })
      } catch (e) {
        console.log(`skipped [${itemId}] ${name}`)
        console.log(e)
        continue
      }

      if (!element) continue // I'm superstitious

      const materialGroupReferences = await element.evaluate(
        (el, { name }) => {
          if (name.toLowerCase() === 'pure titanium crystal') {
            // conlog(el.outerHTML)
            conlog(
              `\nwant: ${name.toLowerCase()}, codex: ${el
                .querySelector('.dt-title a b')
                .textContent.toLowerCase()}, match? ${
                name.toLowerCase() ===
                el.querySelector('.dt-title a b').textContent.toLowerCase()
              }`
            )

            conlog(el.querySelectorAll('.dt-reward > div').length)

            conlog('\n\n')
          }

          if (
            el.querySelector('.dt-title a b').textContent.toLowerCase() !==
              name.toLowerCase() ||
            el.querySelectorAll('.dt-reward > div').length !== 1
          ) {
            return []
          }

          return [...el.querySelectorAll('.dt-level + .dt-reward:has(a)')].map(
            e =>
              [...e.querySelectorAll('a')]
                .filter(a => a.href.includes('materialgroup'))
                .map(a => +a.href.split('/').filter(Boolean).at(-1))
          )
        },
        { name }
      )

      const mgPage = await browser.newPage()
      await mgPage.setRequestInterception(true)

      mgPage.on('request', request =>
        /image|stylesheet|font/.test(request.resourceType()) &&
        !request.isInterceptResolutionHandled()
          ? request.respond({ status: 200, body: 'aborted' })
          : request.continue()
      )

      for (const matGroup of materialGroupReferences.flat(Infinity)) {
        let mgItemElement

        if (getCachedMgItem(matGroup)) continue

        await mgPage.goto(`${ROOT_MATGROUP_URL}${matGroup}`)

        try {
          mgItemElement = await mgPage.waitForSelector('.card-body td a', {
            timeout: 5000,
          })
        } catch {
          console.log(`skipped [${itemId}] ${name}`)
          continue
        }

        const matGroupItem = await mgItemElement.evaluate(
          a => +a.href.split('/').filter(Boolean).at(-1)
        )

        updateMgItemCache(matGroup, matGroupItem)
      }

      await mgPage.close()

      const allRecipesForPotion = await element.evaluate((el, mgItemList) => {
        // hmm...surely this very specific combination of selectors
        // will never change, breaking the entire application...

        return [...el.querySelectorAll('.dt-level + .dt-reward:has(a)')].map(
          e =>
            [...e.querySelectorAll('a')]
              .map(a => ({
                quant: +a.querySelector('.quantity_small').textContent,
                id: a.href.includes('materialgroup')
                  ? mgItemList?.[+a.href.split('/').filter(Boolean).at(-1)]
                  : +a.href.split('/').filter(Boolean).at(-1),
              }))
              .filter(i => !!i.id)
        )
      }, MATGROUP_ITEM_CACHE)

      console.log(allRecipesForPotion)

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

      await page.close()
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
  }

  await browser.close()
  killBrowser()
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

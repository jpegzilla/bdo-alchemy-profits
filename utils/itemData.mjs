import puppeteer from 'puppeteer'
import axios from 'axios'
import chalk from 'chalk'

const ROOT_URL = 'https://bdocodex.com/us/item/'

const minimalPuppeteerArgs = [
  '--autoplay-policy=user-gesture-required',
  '--disable-background-networking',
  '--disable-background-timer-throttling',
  '--disable-backgrounding-occluded-windows',
  '--disable-breakpad',
  '--disable-client-side-phishing-detection',
  '--disable-component-update',
  '--disable-default-apps',
  '--disable-dev-shm-usage',
  '--disable-domain-reliability',
  '--disable-extensions',
  '--disable-features=AudioServiceOutOfProcess',
  '--disable-hang-monitor',
  '--disable-ipc-flooding-protection',
  '--disable-notifications',
  '--disable-offer-store-unmasked-wallet-cards',
  '--disable-popup-blocking',
  '--disable-print-preview',
  '--disable-prompt-on-repost',
  '--disable-renderer-backgrounding',
  '--disable-setuid-sandbox',
  '--disable-speech-api',
  '--disable-sync',
  '--hide-scrollbars',
  '--ignore-gpu-blacklist',
  '--metrics-recording-only',
  '--mute-audio',
  '--no-default-browser-check',
  '--no-first-run',
  '--no-pings',
  '--no-sandbox',
  '--no-zygote',
  '--password-store=basic',
  '--use-gl=swiftshader',
  '--use-mock-keychain',
  '--fast-start',
]

export const getItemCodexData = async itemIdList => {
  console.log(
    `\nI'm getting the ${chalk.cyan(
      'recipe book.'
    )} hold on! I like to take my time~!`
  )

  const browser = await puppeteer.launch({
    headless: true,
    args: minimalPuppeteerArgs,
    ignoreHTTPSErrors: true,
    userDataDir: './puppeteer_cache',
  })

  const recipes = []

  console.log()

  for (const { mainKey: itemId, name, minPrice } of itemIdList) {
    if (!itemId || isNaN(itemId))
      throw new TypeError('itemId must be a number.')

    const url = `${ROOT_URL}${itemId}`

    try {
      const pageString = await axios.get(url)
      if (!pageString.data.includes('ProductRecipeTable')) continue

      const page = await browser.newPage()
      await page.goto(url)

      process.stdout.cursorTo(0)
      process.stdout.clearLine()
      process.stdout.write(
        `  let's read the recipe for ${chalk.yellow(
          `[${name.toLowerCase()}]`
        )}. hmm...`
      )

      let element
      try {
        element = await page.waitForSelector(
          '#MProductRecipeTable, #ProductRecipeTable',
          { timeout: 10_000 }
        )
      } catch {
        console.log(`skipped [${itemId}] ${name}`)
        continue
      }

      if (!element) continue // I'm superstitious

      const allRecipesForPotion = await element.evaluate(el =>
        // hmm...surely this very specific combination of selectors
        // will never change, breaking the entire application...
        [...el.querySelectorAll('.dt-level + .dt-reward:has(a)')].map(e =>
          [...e.querySelectorAll('a')].map(a => ({
            quant: +a.querySelector('.quantity_small').textContent,
            id: +a.href.split('/').filter(Boolean).at(-1),
          }))
        )
      )

      recipes.push({
        item: name,
        recipeList: allRecipesForPotion,
        price: minPrice,
        id: itemId,
      })

      await page.close()
    } catch (e) {
      console.log(
        chalk.red(
          '=================== ERROR (ERIS HAS FUCKED UP) ===================\n'
        )
      )
      console.log(
        "if you're not messing with the code, you should never see this. tell @jpegzilla (that's eris)"
      )
      console.log(`${itemId}, ${name}`)
      console.error('the bdocodex parser thing has broken. output:\n')
      console.error(e)
      console.log(
        chalk.red(
          '\n=================== ERROR (ERIS HAS FUCKED UP) ==================='
        )
      )
    }
  }

  await browser.close()

  process.stdout.cursorTo(0)
  process.stdout.clearLine()
  console.log(
    `  ♫ that's all the recipes! looks like there are ${chalk.cyan(
      recipes.length
    )} of them in total. let's see how much it costs to make these!`
  )

  return recipes
}

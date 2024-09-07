import readline from 'readline-sync'
import chalk from 'chalk'

import { getConsumableMarketData } from './utils/index.mjs'

const options = [
  'offensive',
  'defensive',
  'functional',
  'other',
  'potion',
  'blood',
  'oil',
  'alchemy stone',
  'reagent',
  'black stone',
  'magic crystal',
  // 'metal and ore', // taking this out because often the recipes are inaccurate
  // 'furniture', // many of these require houses to craft in, which is insanely slow usually
  'all',
]

console.log(
  `\n♫ hello! oh? you want to sell ${chalk.yellow(
    'potions'
  )} today? that sounds like fun!`
)
console.log(`\n♫ let's practice ${chalk.yellow('alchemy')} together~!`)
console.log('\n♫ offensive, defensive, or maybe all at once...?')

const index = readline.keyInSelect(
  options,
  'which category shall we try to make today?'
)

const subcategory = options[index]

if (index === -1) {
  console.log(
    `\nnever mind, let's do some ${chalk.yellow(
      'cooking'
    )} together instead! ♫\n`
  )
}

if (!options.includes(subcategory) && subcategory) {
  console.log(
    "\nI don't know that category! I only know about offensive, defensive, functional, and potion consumables. try one of those categories!\n"
  )
}

const main = async () => {
  if (options.includes(subcategory)) {
    console.log(
      `\n♫ let's see if ${chalk.cyan(
        subcategory
      )} items are profitable today~ ♫`
    )

    if (subcategory === 'all') await getConsumableMarketData(subcategory, true)
    else await getConsumableMarketData(subcategory)
  }

  await readline.question('(press enter to exit)')

  console.log()
  process.exit()
}

main()

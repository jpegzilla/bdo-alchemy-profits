import './utils/prototypeExtensions.mjs'
import readline from 'readline-sync'
import chalk from 'chalk'

import { getConsumableMarketData } from './utils/index.mjs'

const options = ['offensive', 'defensive', 'functional', 'potion']

console.log(
  `\n♫ hello! oh? you want to sell ${chalk.yellow(
    'potions'
  )} today? that sounds like fun!`
)
console.log(`\n♫ let's practice ${chalk.yellow('alchemy')} together~!`)
console.log('\n♫ offensive, defensive, functional, potion...')
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
  process.exit()
}

if (!options.includes(subcategory)) {
  console.log(
    "\nI don't know that category! I only know about offensive, defensive, functional, and potion consumables. try one of those categories!\n"
  )

  process.exit()
}

console.log(
  `\n♫ let's see if ${chalk.cyan(
    subcategory
  )} consumables are profitable today~ ♫`
)

await getConsumableMarketData(subcategory)

process.exit()

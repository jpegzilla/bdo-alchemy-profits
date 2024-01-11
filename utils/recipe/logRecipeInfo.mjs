import chalk from 'chalk'

export const logRecipeInfo = (
  shouldShowRecipes,
  anyProfitsNegative,
  recipes,
  outOfStockItems = []
) => {
  if (shouldShowRecipes) {
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
    console.log(recipes.map(e => e.information).join('\n'))
  } else {
    console.log(
      `\nit's not practical for us to buy those ingredients...come on, let's go ${chalk.yellow(
        'gathering together! ♫'
      )}\n`
    )
    if (outOfStockItems.length > 0)
      console.log(
        `maybe we'll find some ${chalk.yellow(`[${outOfStockItems[0]}]`)}${
          outOfStockItems[1]
            ? ` or ${chalk.yellow(`[${outOfStockItems[1]}]!`)}`
            : '!'
        }`
      )
    console.log()
  }
}

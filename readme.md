# bdo (market) alchemy profit tool

this is a tool that searches the central market for potions that you can make profit on just by buying all the ingredients and selling the result.

of course, there are usually none of these! sometimes there are a few, but they're typically very low volume, limiting total profits. BUT, if there are any, this tool will find them!

this doesn't take into account market tax or anything like that. it just shows raw profits based on market price of the potion versus market price of the ingredients.

finally, if you really want to make profit on the market, you basically have to go out and gather super rare ingredients yourself. good  luck!

## how to use

if you have node.js installed on your computer, you can use the source code.

1.  clone this repo
2.  install yarn (`npm i -g yarn`)
3.  install dependencies (`yarn`)
4.  run the script (`yarn start`)

### standalone executable

work in progress.

I'm trying to package this up into an executable, but it's making me regret even writing this in javascript. HELP. I have tried `pkg`, `nexe`, `babel` + `ncc` + `pkg`, `warp`, `babel` + `nexe`, and a few other things I can't even remember. I have no clue what to do.

todo:

-   [ ] cache ingredient prices
-   [ ] add option to search for all possible alchemy consumables
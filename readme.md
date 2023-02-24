# bdo (market) alchemy profit tool

this is a tool that searches the central market for potions and other items that you can make profit on just by buying all the ingredients and selling the result.

![an example readout from the script](./screenshots/example_one.png)

of course, there are usually none of these! sometimes there are a few, but they're typically very low volume, limiting total profits. BUT, if there are any, this tool will find them!

this takes into account market tax and shows the gross potential profit as well as the taxed profit - but it currently assumes you have the value pack and that your fame is level 1 (family fame >= 1000).

finally, if you really want to make profit on the market, you basically have to go out and gather super rare ingredients yourself. good  luck!

## how to use

if you have node.js installed on your computer, you can use the source code.

1.  `git clone git@github.com:jpegzilla/bdo-alchemy-profits.git`
1.  cd into `bdo-alchemy-profits`
1.  install yarn (`npm i -g yarn`)
1.  install dependencies (`yarn`)
1.  run the script (`yarn start`)
1.  pick a category to search in and wait! it may take a while, as the script scrapes bdocodex.com for recipe information.

![the script options selection](./screenshots/example_two.png)

### standalone executable

work in progress.

I'm trying to package this up into an executable, but it's making me regret even writing this in javascript. HELP. I have tried `pkg`, `nexe`, `babel` + `ncc` + `pkg`, `warp`, `babel` + `nexe`, and a few other things I can't even remember. I have no clue what to do.

todo:

-   [ ] cache ingredient prices
-   [x] add option to search for all possible alchemy consumables
-   [x] account for market tax
-   [x] warn about low daily volume for ingredients and consumables
-   [ ] add a `--silent` or `--minimal` option to just show bare output
-   [ ] **critical:** figure out how to get recipe information without scraping bdocodex. this would speed up the script by a huge amount.
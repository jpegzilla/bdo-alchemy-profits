# bdo (market) alchemy profit tool

this is a tool that searches the central market for potions and other items that you can make profit on just by buying all the ingredients and selling the result.

it assumes you have high enough alchemy mastery (artisan 1) for max procs on recipes that are affected, such as bloods and elixirs.

![an example readout from the script](./screenshots/example_one.png)

of course, there are usually none of these! sometimes there are a few, but they're typically very low volume, limiting total profits. BUT, if there are any, this tool will find them!

this takes into account market tax and shows the gross potential profit as well as the taxed profit - but it currently assumes you have the value pack and that your fame is level 1 (family fame >= 1000).

it will also tell you the maximum possible amount of items you can craft (by buying all the available ingredients). if an npc sells the item you need, that will be listed as well.

![an example listing some ingredients sold by npcs.](./screenshots/example_three.png)

finally, if you really want to make profit on the market, you basically have to go out and gather super rare ingredients yourself. if you can sap all fifteen thornwood trees on the map or pick all three truffle mushrooms, you'll be rolling in cash! and if you _really_ wanna make the big bucks, head to tunkuta! I'm sure you'll have no trouble at all crafting those 10+ million silver potions if you get some turo blood and hearts...although it seems like 99% of turos must be heartless, bloodless vampires or something. or you could harvest 10000 delotia and get a handful of remnants of burnt spirits for corrupt oil of immortality ;P

good luck!

## how to use

if you have [ruby](https://www.ruby-lang.org/en/) installed on your computer, you can use the source code.

1.  `git clone git@github.com:jpegzilla/bdo-alchemy-profits.git`
1.  `cd bdo-alchemy-profits`
1.  install [rake](https://ruby.github.io/rake/) (`gem install rake`)
1.  install dependencies (`rake install`)
1.  run the script (`rake start`)
1.  pick a category to search in and wait! it may take a while, as the script scrapes [bdocodex.com](https://bdocodex.com/us/) for recipe information. it will try to do this as little as possible, because after the first time most recipes will be cached.

![the script options selection](./screenshots/example_two.png)

## standalone executable (outdated)

standalone executables are available on the [releases page](https://github.com/jpegzilla/bdo-alchemy-profits/releases)!

currently, there's only a build for windows. I don't have a mac or linux machine to test with, so I won't provide binaries for other operating systems yet.

## todo:

-   [x] cache ingredient prices
-   [x] add option to search for all possible alchemy consumables
-   [x] account for market tax
-   [x] warn about low daily volume for ingredients and consumables
-   [ ] add a `--silent` or `--minimal` option to just show bare output
-   [x] **critical:** figure out how to get recipe information without scraping bdocodex. this would speed up the script by a huge amount.
-   [x] make it work
-   [ ] make the code prettier
-   [ ] make it fast
-   [ ] detect optimal matgroup item to use (i.e. purified water is easier to obtain than distilled water, but they're in the same matgroup)
-   [x] make executable that ships with external chromium (for puppeteer)
-   [ ] add support for non na / eu regions
-   [ ] allow user specification of region
-   [ ] allow the script to just start over from the options select when finished, so users can select another category without restarting the whole thing
-   [ ] allow users to specify if they wish to show unprofitable recipes / recipes with out-of-stock ingredients
-   [ ] allow users to specify their own request verification token

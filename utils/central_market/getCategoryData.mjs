import axios from 'axios'
import env from './../../env.mjs'

const { RVT, REQUEST_OPTS } = env

const categorySearchOptions = (url, searchURL) => [
  {
    name: 'black stone',
    url,
    queryString: `${RVT}&mainCategory=30&subcategory=1`,
    update: data => ({ blackStoneResponse: data }),
  },
  {
    name: 'blood',
    url: searchURL,
    queryString: `${RVT}&searchText='s+blood`,
    update: data => ({ bloodResponse: data }),
  },
  {
    name: 'reagent',
    url: searchURL,
    queryString: `${RVT}&searchText=reagent`,
    update: data => ({ reagentResponse: data }),
  },
  {
    name: 'oil',
    url: searchURL,
    queryString: `${RVT}&searchText=oil+of`,
    update: data => ({ oilResponse: data }),
  },
  {
    name: 'alchemy stone',
    url: searchURL,
    queryString: `${RVT}&searchText=stone+of`,
    update: data => ({ alchemyStoneResponse: data }),
  },
  {
    name: 'magic crystal',
    url: searchURL,
    queryString: `${RVT}&searchText=magic+crystal`,
    update: data => ({ magicCrystalResponse: data }),
  },
  // {
  //   name: 'metal and ore',
  //   url,
  //   queryString: `${RVT}&mainCategory=25&subcategory=1`,
  //   update: data => ({ metalAndOreResponse: data }),
  // },
]

const doIfCategoryMatches = async (
  { subcatToMatch, subcategory, allSubcategories },
  cb
) => {
  if (subcategory === subcatToMatch || allSubcategories) await cb()
}

export const aggregateCategoryData = async (
  url,
  searchURL,
  subcategory,
  allSubcategories
) => {
  const makeMatchOptions = subcatToMatch => ({
    subcatToMatch,
    subcategory,
    allSubcategories,
  })

  let aggregateResponse = {}

  for (const categoryOptions of categorySearchOptions(url, searchURL)) {
    await doIfCategoryMatches(
      makeMatchOptions(categoryOptions.name),
      async () => {
        const data = await axios.post(
          categoryOptions.url,
          categoryOptions.queryString,
          REQUEST_OPTS
        )

        Object.assign(aggregateResponse, categoryOptions.update(data))
      }
    )
  }

  return aggregateResponse
}

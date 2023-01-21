import './utils/prototypeExtensions.mjs'
import { getConsumableMarketData } from './utils/index.mjs'

const elements = []

elements.forEach(({ name, element }) => {
  if (name && element) customElements.define(name, element)
})

await getConsumableMarketData()

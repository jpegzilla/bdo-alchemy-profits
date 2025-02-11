export const deepPermute = (input, limit) => {
  const makePermutations = (list, n = 0, result = [], current = []) => {
    // n === limit probably not useful here...
    if (n === list.length && n === limit) result.push(current)
    else
      list[n].forEach(item =>
        makePermutations(list, n + 1, result, [...current, item])
      )

    return result
  }

  return makePermutations(input)
}

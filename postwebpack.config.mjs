import glob from 'glob'

export default {
  mode: 'production',
  entry: {
    js: glob.sync('./dist/wp/**/*.js'),
  },
  target: 'node',
  output: {
    path: 'D:/documents/development/bdo-alchemy-profits/dist/pwp',
    chunkFormat: 'commonjs',
  },
}

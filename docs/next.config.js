const withNextra = require('nextra')({
  theme: 'nextra-theme-docs',
  themeConfig: './theme.config.js',
  unstable_flexsearch: true,
  unstable_staticImage: true,
  output: 'export',
})

module.exports = withNextra({
  images: {
    unoptimized: true,
  },
})

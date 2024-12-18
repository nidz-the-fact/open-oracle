import { useRouter } from 'next/router'

const Logo = ({ height }) => (
  <svg height={height} viewBox='0 0 70 70' fill='none'>
    <circle cx='35' cy='35' r='35' fill='currentColor' />
  </svg>
)

export default {
  banner: () => (
    <p>
      🎉 This is a beta version only. feeel free!
    </p>
  ),
  projectLink: 'https://github.com/nidz-the-fact/open-oracle',
  docsRepositoryBase: 'https://github.com/nidz-the-fact/open-oracle/tree/main/docs/pages',
  gitTimestamp: true,
  search: true,
  titleSuffix: '',
  unstable_flexsearch: true,
  unstable_faviconGlyph: '⚫️',
  floatTOC: true,
  logo: () => {
    const { route } = useRouter()
    return (
      <>
        <Logo height={18} />
        {route === '/' ? null : (
          <span
            className='mx-2 font-extrabold hidden md:inline select-none'
            title='Open Oracle'
            style={{ whiteSpace: 'nowrap' }}
          >
            Open Oracle
          </span>
        )}
      </>
    )
  },
  head: ({ title, meta }) => {
    const ogImage =
      'https://raw.githubusercontent.com/nidz-the-fact/open-oracle/refs/heads/main/openoracle-present.gif'

    return (
      <>
        <meta name='msapplication-TileColor' content='#ffffff' />
        <meta httpEquiv='Content-Language' content='en' />
        <meta
          name='description'
          content={meta.description || 'Connect Data API on Chain.'}
        />
        <meta
          name='og:description'
          content={meta.description || 'Connect Data API on Chain.'}
        />
        <meta name='twitter:card' content='summary_large_image' />
        <meta name='twitter:site' content='https://github.com/nidz-the-fact/open-oracle' />
        <meta name='twitter:image' content={ogImage} />
        <meta name='og:title' content='Open Oracle' />
        <meta name='og:image' content={ogImage} />
        <meta name='apple-mobile-web-app-title' content='Open Oracle' />
      </>
    )
  },
  footerText: ({ locale }) => {
    return (
      <p className='no-underline text-current font-semibold'>
        © 2024-{new Date().getFullYear()} OpenOracle (API)., Powered by {' '}
        <a
          href='https://linktr.ee/nid_z'
          target='_blank'
          rel='noopener'
          className='no-underline font-semibold'
        >
          Nidz 
        </a>
        .
      </p>
    )
  },
  footerEditLink: () => {
    return 'Edit this page'
  },
  
}

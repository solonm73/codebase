'use client'

import { useState } from 'react'

const EXTERNAL_LOGO_URL = 'https://www.partsoftware.com/images/logo/partsoftware.png'
const FALLBACK_LOGO_URL = '/images/part-logo-fallback.svg'

export default function Home() {
  const [logoSrc, setLogoSrc] = useState(EXTERNAL_LOGO_URL)

  return (
    <div style={{
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      minHeight: '100vh',
      gap: '2rem',
      padding: '1rem'
    }}>
      <div style={{
        position: 'relative',
        width: '6rem',
        height: '6rem'
      }}>
        <img
          src={logoSrc}
          alt="part Logo"
          onError={() => setLogoSrc(FALLBACK_LOGO_URL)}
          style={{
            width: '100%',
            height: '100%',
            objectFit: 'contain'
          }}
        />
      </div>
    </div>
  )
}

export default function Home() {
  return (
    <main style={{ maxWidth: 560, margin: '15vh auto', padding: 24 }}>
      <p style={{ color: '#6E9DD9', fontWeight: 600, letterSpacing: '.08em', fontSize: 12 }}>MAILLER STUDIO</p>
      <h1 style={{ margin: '8px 0 12px', fontSize: 34, letterSpacing: '-0.03em' }}>API en ligne</h1>
      <p style={{ color: '#A0A8B3', lineHeight: 1.6 }}>
        Ce serveur alimente l’application Mailler Studio. Connectez-vous avec votre compte (e-mail et mot de passe) ;
        au premier lancement, l’application propose de créer le compte administrateur.
      </p>
      <a
        href="/app/"
        style={{
          display: 'inline-block',
          marginTop: 16,
          padding: '12px 22px',
          borderRadius: 12,
          background: 'linear-gradient(135deg, #3D6DAA, #1E8572)',
          color: '#ffffff',
          fontWeight: 600,
          textDecoration: 'none',
        }}
      >
        Ouvrir l’application
      </a>
    </main>
  );
}

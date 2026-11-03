export const metadata = { title: 'Mailler Studio API' };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="fr">
      <body style={{ margin: 0, fontFamily: 'system-ui, sans-serif', background: '#0B0D10', color: '#F2F3F4' }}>
        {children}
      </body>
    </html>
  );
}

import { useEffect, useState } from 'react'
import config from '../app.config.json'
import { api } from './lib/api.js'
import CollectionPanel from './components/CollectionPanel.jsx'
import StashTotals from './components/StashTotals.jsx'

function HealthBadge() {
  const [state, setState] = useState('checking')

  useEffect(() => {
    api.health().then(() => setState('live')).catch(() => setState('offline'))
  }, [])

  const styles = {
    checking: 'border-edge text-muted',
    live: 'border-accent text-accent',
    offline: 'border-edge text-muted line-through',
  }
  return (
    <span className={`rounded-full border px-3 py-1 text-xs uppercase tracking-widest ${styles[state]}`}>
      API {state}
    </span>
  )
}

export default function App() {
  // Bumped after every add or delete so the totals refresh.
  const [statsVersion, setStatsVersion] = useState(0)
  const refreshStats = () => setStatsVersion((v) => v + 1)

  useEffect(() => {
    document.documentElement.dataset.theme = config.theme
    document.title = config.displayName
  }, [])

  return (
    <div className="min-h-screen bg-surface text-ink">
      <header className="border-b border-edge">
        <div className="mx-auto flex max-w-5xl flex-wrap items-center justify-between gap-4 px-6 py-8">
          <div>
            <h1 className="font-display text-4xl font-bold tracking-tight">{config.displayName}</h1>
            <p className="mt-2 max-w-xl text-muted">{config.description}</p>
          </div>
          <HealthBadge />
        </div>
      </header>

      <main className="mx-auto grid max-w-5xl gap-8 px-6 py-10">
        <StashTotals version={statsVersion} />
        {config.collections.map((collection) => (
          <CollectionPanel key={collection.name} collection={collection} onChange={refreshStats} />
        ))}
      </main>

      <footer className="mx-auto max-w-5xl px-6 pb-10 text-xs text-muted">
        Built on the Skeleton Crew serverless template.
      </footer>
    </div>
  )
}

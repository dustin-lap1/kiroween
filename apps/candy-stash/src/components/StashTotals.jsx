import { useEffect, useState } from 'react'
import { api } from '../lib/api.js'

function Tile({ icon, label, value, detail }) {
  return (
    <div className="rounded-2xl border border-edge bg-panel p-6">
      <p className="text-sm uppercase tracking-widest text-muted">
        <span aria-hidden="true" className="mr-2">{icon}</span>
        {label}
      </p>
      <p className="mt-2 font-display text-5xl font-bold text-accent" aria-live="polite">
        {value}
      </p>
      {detail && <p className="mt-1 text-sm text-muted">{detail}</p>}
    </div>
  )
}

// Totals across every stored item (GET /api/stats). `version` changes after
// each add or delete, which triggers a refresh.
export default function StashTotals({ version }) {
  const [stats, setStats] = useState(null)
  const [error, setError] = useState('')

  useEffect(() => {
    let cancelled = false
    setError('')
    api.stats()
      .then((s) => { if (!cancelled) setStats(s) })
      .catch((e) => { if (!cancelled) setError(e.message) })
    return () => { cancelled = true }
  }, [version])

  const fmt = (n) => (stats ? n.toLocaleString() : 'Counting...')
  const plural = (n, one, many) => `${n.toLocaleString()} ${n === 1 ? one : many}`

  return (
    <section aria-label="Totals" className="grid gap-4">
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <Tile
          icon="🍬"
          label="Pieces of candy"
          value={fmt(stats?.candyPieces)}
          detail={stats && plural(stats.candyItems, 'kind of candy', 'kinds of candy')}
        />
        <Tile
          icon="🎃"
          label="Visitors"
          value={fmt(stats?.visitors)}
          detail={stats && plural(stats.visitorGroups, 'group', 'groups')}
        />
      </div>
      {error && <p role="alert" className="text-sm text-accent">Could not count the stash: {error}</p>}
    </section>
  )
}

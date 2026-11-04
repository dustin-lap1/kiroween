import { useCallback, useEffect, useState } from 'react'
import { api } from '../lib/api.js'

const inputClass =
  'w-full rounded-lg border border-edge bg-surface px-3 py-2 text-ink placeholder:text-muted focus:border-accent focus:outline-none'

function emptyDraft(fields) {
  return Object.fromEntries(fields.map((f) => [f.name, f.type === 'boolean' ? false : '']))
}

function Field({ collection, field, value, onChange }) {
  const id = `field-${collection}-${field.name}`
  const common = { id, name: field.name, required: field.required, maxLength: field.maxLength }
  const numberProps = field.type === 'number'
    ? { min: field.min, max: field.max, step: field.integer ? 1 : 'any', inputMode: field.integer ? 'numeric' : 'decimal' }
    : {}
  let control
  if (field.type === 'textarea') {
    control = <textarea {...common} rows={3} className={inputClass} value={value} onChange={(e) => onChange(e.target.value)} />
  } else if (field.type === 'select') {
    control = (
      <select {...common} className={inputClass} value={value} onChange={(e) => onChange(e.target.value)}>
        <option value="">Choose...</option>
        {field.options.map((o) => <option key={o} value={o}>{o}</option>)}
      </select>
    )
  } else if (field.type === 'boolean') {
    control = <input id={id} type="checkbox" className="h-5 w-5 accent-accent" checked={value} onChange={(e) => onChange(e.target.checked)} />
  } else {
    const type = field.type === 'number' ? 'number' : field.type === 'url' ? 'url' : field.type === 'email' ? 'email' : 'text'
    control = <input {...common} {...numberProps} type={type} className={inputClass} value={value} onChange={(e) => onChange(e.target.value)} />
  }
  return (
    <label htmlFor={id} className="grid gap-1 text-sm">
      <span className="text-muted">{field.label ?? field.name}{field.required ? ' *' : ''}</span>
      {control}
    </label>
  )
}

function formatValue(field, value) {
  if (value === undefined || value === null || value === '') return null
  if (field.type === 'boolean') return value ? 'Yes' : 'No'
  return String(value)
}

export default function CollectionPanel({ collection, onChange }) {
  const { name, label, itemLabel = 'item', fields, titleField = fields[0]?.name } = collection
  const [items, setItems] = useState([])
  const [loading, setLoading] = useState(true)
  const [draft, setDraft] = useState(() => emptyDraft(fields))
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)

  const load = useCallback(() => {
    setLoading(true)
    api.list(name)
      .then(setItems)
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false))
  }, [name])

  useEffect(load, [load])

  async function submit(event) {
    event.preventDefault()
    setBusy(true)
    setError('')
    try {
      const payload = Object.fromEntries(
        fields
          .filter((f) => draft[f.name] !== '')
          .map((f) => [f.name, f.type === 'number' ? Number(draft[f.name]) : draft[f.name]]),
      )
      const created = await api.create(name, payload)
      setItems((current) => [created, ...current])
      setDraft(emptyDraft(fields))
      onChange?.()
    } catch (e) {
      setError(e.message)
    } finally {
      setBusy(false)
    }
  }

  async function remove(id) {
    setError('')
    try {
      await api.remove(name, id)
      setItems((current) => current.filter((i) => i.id !== id))
      onChange?.()
    } catch (e) {
      setError(e.message)
    }
  }

  return (
    <section className="rounded-2xl border border-edge bg-panel p-6">
      <h2 className="font-display text-2xl font-semibold">{label}</h2>

      <form onSubmit={submit} className="mt-4 grid gap-3">
        {fields.map((field) => (
          <Field
            key={field.name}
            collection={name}
            field={field}
            value={draft[field.name]}
            onChange={(v) => setDraft((d) => ({ ...d, [field.name]: v }))}
          />
        ))}
        <div className="flex items-center gap-3">
          <button
            type="submit"
            disabled={busy}
            className="rounded-lg bg-accent px-4 py-2 font-semibold text-accent-ink disabled:opacity-50"
          >
            {busy ? 'Saving...' : `Add ${itemLabel}`}
          </button>
          {error && <p role="alert" className="text-sm text-accent">{error}</p>}
        </div>
      </form>

      <ul className="mt-6 grid gap-3">
        {loading && items.length === 0 && <li className="text-sm text-muted">Loading...</li>}
        {!loading && items.length === 0 && <li className="text-sm text-muted">No {itemLabel}s yet.</li>}
        {items.map((item) => (
          <li key={item.id} className="rounded-xl border border-edge bg-surface p-4">
            <div className="flex items-start justify-between gap-4">
              <h3 className="font-semibold">{item[titleField]}</h3>
              <button
                type="button"
                onClick={() => remove(item.id)}
                className="text-xs text-muted hover:text-accent"
                aria-label={`Delete ${itemLabel}`}
              >
                Delete
              </button>
            </div>
            <dl className="mt-2 grid gap-1 text-sm">
              {fields
                .filter((f) => f.name !== titleField && formatValue(f, item[f.name]))
                .map((f) => (
                  <div key={f.name} className="flex gap-2">
                    <dt className="text-muted">{f.label ?? f.name}:</dt>
                    <dd className="whitespace-pre-wrap">{formatValue(f, item[f.name])}</dd>
                  </div>
                ))}
            </dl>
            <p className="mt-2 text-xs text-muted">{new Date(item.createdAt).toLocaleString()}</p>
          </li>
        ))}
      </ul>
    </section>
  )
}

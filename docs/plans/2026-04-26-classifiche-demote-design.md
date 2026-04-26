# Design: classifiche — espansione/collasso e "demote" gruppi

## Goal

Sulla pagina `/classifica`:

1. Rendere la sezione di ogni classe (Classe 1, Classe 4) collassabile/espandibile.
2. Permettere di "spostare sotto" (demote) i gruppi `(classe, materia)` non interessanti, senza cancellarli.
3. Pulsante globale per nascondere tutti i demoted; pulsante globale per ripristinare.

Lo stato vive in `localStorage` — è una preferenza UI di un singolo utente, sopravvive ai nuovi caricamenti ASCII perché il `codice` materia è stabile.

## Architettura

Modifica solo lato view + un blocco JS inline. Niente schema, niente nuovi controller/route.

- `show.html.erb` — wrapper root, header con i due pulsanti globali, ogni classe in `<details>` con due "zone" (primary, demoted) separate da divider.
- `_classifica.html.erb` — `data-materia-codice` sull'outer `<details>`; due pulsantini in `<summary>`: `↓` (demote) e `↑` (promote).
- Script vanilla JS in fondo a `show.html.erb`: legge stato da localStorage al caricamento, riordina il DOM, gestisce click via event delegation.

> Nota: scelto JS inline anziché Stimulus perché la gem `stimulus-rails` è installata ma non configurata (`app/javascript` non esiste). Aggiungere importmap+stimulus per una sola pagina sarebbe sproporzionato. Migrazione a Stimulus è banale se in futuro arriva altra interattività.

## Storage shape

```js
// chiave "capo:demoted" — lista di "classe:codice"
["1:200", "1:300", "4:1200"]

// chiave "capo:hideDemoted" — bool
"true" | "false"
```

La chiave include sia classe sia codice materia: la stessa materia può essere demoted in cl1 ma non in cl4.

## Data flow

1. **Page load**: il JS legge `demoted` e `hideDemoted` da localStorage; per ogni classe sposta i `<details>` materia nelle zone giuste, apre/chiude in base allo stato, mostra/nasconde la zona demoted.
2. **Click `↓` su una materia**: aggiunge la chiave a `demoted`, salva, ri-applica stato → la card scivola sotto e si chiude.
3. **Click `↑` su una materia demoted**: rimuove la chiave, salva, ri-applica stato → torna sopra aperta.
4. **Click "Nascondi demoted"**: setta `hideDemoted = true`, ri-applica → la zona inferiore (e divider) sparisce.
5. **Click "Mostra tutto"**: svuota `demoted` e setta `hideDemoted = false` → tutto torna primary, aperto.

## Edge cases

- **localStorage non disponibile / quota piena**: `try/catch` attorno a get/set; in caso di errore, controller parte con stato vuoto e log su console. UI funziona comunque, persistenza salta per quella sessione.
- **JSON corrotto**: `JSON.parse` in `try/catch` → fallback array vuoto; il prossimo save sovrascrive.
- **Chiavi orfane** (materia non più presente dopo un nuovo caricamento): restano in storage, ignorate, non rompono nulla.
- **Click sul bottone in `<summary>`**: il delegated listener intercetta e chiama `e.preventDefault()` per impedire il toggle nativo del `<details>`.

## Testing

Niente system test in questa iterazione: il comportamento è UI puro su una singola pagina e l'app non ha al momento Capybara/headless setup. Verifico manualmente in browser dopo il deploy. I test backend esistenti restano verdi (zero modifiche al controller).

## Out of scope

- Tabella DB delle "combinazioni giuste" (classe-materia) → eventuale evoluzione futura come seed/costante; per ora il toggle utente è sufficiente.
- Mostrare cl2/cl3/cl5 in classifica → i dati sono importati ma non visualizzati per scelta di prodotto.

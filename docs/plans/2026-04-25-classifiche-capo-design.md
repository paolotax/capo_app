# Classifiche capo — Design

Data: 2026-04-25
App: `capo_app` (Rails 8.2.0.alpha, SQLite, Tailwind v4, deploy target: Once)

## Contesto

Il capo distribuisce un file ASCII tab-separated (`ASCI819E_tax.txt`, 23 colonne)
con i totali aggregati nazionali delle adozioni testi: per ogni ISBN, alunni e
sezioni per classe (1..5). La prima colonna è un codice materia (200, 300,
400, ..., 1500). Lo strumento serve a produrre, dato un file, le classifiche
di mercato per **classe × materia**.

Le classi 2, 3 e 5 non hanno libri propri:
- cl2/cl3: vuote nel file (zero alunni/sezioni).
- cl5: contiene "scorrimenti" — il numero di sezioni che scorreranno dalla cl4
  dell'anno corrente alla cl5 dell'anno prossimo. L'ISBN nella riga cl5 è
  spesso quello del libro cl4, non del seguito reale.

L'app è single-user (il capo). Ogni upload sostituisce lo snapshot
precedente. Niente storia, niente multi-tenant.

## Modello dati

```
materie
  id
  codice          integer  UNIQUE
  nome            string
  ordine          integer
  timestamps

caricamenti
  id
  filename        string
  caricato_il     datetime
  righe_count     integer
  timestamps

righe_capo
  id
  caricamento_id  → caricamenti  (on_delete: cascade)
  materia_id      → materie
  classe          integer  (1..5)
  isbn            string
  titolo          string
  autore          string
  editore_codice  string
  editore         string
  sezioni         integer
  alunni          integer
  anno            string
  scorrimento     boolean   (true sse classe = 5)
  flag_elimina_1  string    (col 4 grezza, semantica TBD)
  flag_elimina_2  string    (col 10 grezza, semantica TBD)
  timestamps
  index (classe, materia_id)
  index (caricamento_id)
```

**Replace strategy**: ogni upload crea un nuovo `Caricamento`, importa le righe
in transaction, poi `Caricamento.where.not(id: nuovo.id).destroy_all` (cascade
pulisce le righe vecchie). Sempre 1 snapshot attivo.

**Materia seed** (`db/seeds.rb`): mappa nota dei ~12 codici principali.

```
200  Sussidiario Linguaggi          ord 10
300  Sussidiario Discipline         ord 20
400  Religione                      ord 30
500  Religione                      ord 31
570  Inglese                        ord 40
600  Inglese                        ord 41
650  Inglese                        ord 42
700  Francese                       ord 50
750  Francese                       ord 51
1000 Parascolastica umanistico      ord 60
1050 Sussidiario Discipline (Antrop) ord 21
1100 Parascolastica scientifico     ord 70
1150 Sussidiario Discipline (Scient) ord 22
1200 Libro della Prima              ord 5
1300 Libro della Prima              ord 6
1500 Alternativa Religione          ord 32
```

L'importer, se trova un codice non in tabella, crea
`Materia(codice: X, nome: "Materia #{X}", ordine: 999)` e logga warning.

## Importer + flusso upload

```
app/services/caricamento_capo/parser.rb
app/services/caricamento_capo/importer.rb
```

**Parser**:
- input: path file txt
- output: array di hash `{materia_codice, isbn, titolo, autore, editore_codice,
  editore, anno, flag_elimina_1, flag_elimina_2, righe: [{classe:, sezioni:,
  alunni:}, ...]}`
- una riga del file → fino a 5 elementi `righe_capo` (uno per classe)
- skip righe completamente vuote (zero alunni e zero sezioni su tutte le
  classi)
- nessun filtro sui flag `elimina` (semantica ancora ignota — i campi vengono
  salvati grezzi su `righe_capo`)

**Importer**:
- input: `ActionDispatch::Http::UploadedFile`
- salva file in `tmp/uploads/<timestamp>_<original>` (per debug/replay)
- transaction:
  1. `Caricamento.create!(filename:, caricato_il: Time.current)`
  2. parser → bulk `RigaCapo.insert_all` in chunk da 500
  3. `Caricamento.where.not(id: caricamento.id).destroy_all`
  4. `caricamento.update!(righe_count: ...)`
- ritorna `Caricamento` oppure solleva → rollback completo

## Query

PORO style, `app/queries/`:

```ruby
class ClassificaQuery
  def initialize(classe:, materia:)
    @classe, @materia = classe, materia
  end

  def righe
    base = RigaCapo
             .where(classe: @classe, materia: @materia)
             .where("sezioni > 0")
             .group(:isbn, :titolo, :autore, :editore)
             .select("isbn, titolo, autore, editore,
                      SUM(sezioni) AS sezioni,
                      SUM(alunni)  AS alunni")
             .order("sezioni DESC")
    tot = base.sum(&:sezioni).to_f
    base.map { |r| r.attributes.merge("quota" => (r.sezioni / tot * 100).round(1)) }
  end
end

class ClassificaEditoreQuery
  # stesso pattern, GROUP BY editore
end
```

## UI

Routes:
```
root "classifiche#show"
resource  :classifica, only: :show
resources :caricamenti, only: %i[new create destroy]
```

`ClassificheController#show`:
- carica `Materia.order(:ordine)` includendo le sole materie con righe presenti
  per cl1 o cl4
- view a 2 colonne grosse: Classe 1, Classe 4
- per ogni classe, tab/sezione per ogni materia
- per ogni materia: tabella `pos | titolo | autore | editore | sezioni |
  alunni | quota%`
- in fondo, mini-aggregato per editore della stessa materia
- styling: Tailwind v4, niente JS pesante; tab via radio+CSS

Se `RigaCapo.count == 0` → home redirige a `caricamenti#new`.

Auth: HTTP basic in `ApplicationController` (env `APP_PASSWORD`). Su Once
single-user, niente Devise.

## Test

- 1 fixture txt mini (5-10 righe) sotto `test/fixtures/files/`
- unit test parser: parsing corretto, skip righe vuote
- unit test importer end-to-end: file → caricamento + righe + cleanup
- query test: classifica produce ordini e quote attesi
- system test smoke: upload file → classifiche visibili

## Cosa NON è in questo piano

- Multi-anno/multi-snapshot (replace totale per ora).
- Filtri/ricerca avanzati nelle classifiche.
- Export CSV/PDF (eventuale aggiunta successiva).
- Avo o pannello admin.
- Cambio codici/normalizzazione editori (l'editore resta denormalizzato).

## Step di implementazione (proposti, in ordine)

1. Migrazioni + modelli (`Materia`, `Caricamento`, `RigaCapo`) + seed materie.
2. Parser + tests.
3. Importer + tests.
4. ClassificaQuery + ClassificaEditoreQuery + tests.
5. ClassificheController + view (con stato vuoto → CTA upload).
6. CaricamentiController + form upload + redirect.
7. HTTP basic auth.
8. System test end-to-end.
9. Pulizia, README, deploy config Once.

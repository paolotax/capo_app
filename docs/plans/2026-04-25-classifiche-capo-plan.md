# Classifiche capo — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a single-user Rails app that ingests an ASCII tab-separated file of national textbook adoption aggregates and produces market-share rankings by class × subject (materia).

**Architecture:** Three ActiveRecord models (`Materia`, `Caricamento`, `RigaCapo`) on SQLite. A `CaricamentoCapo::Parser` reads the txt file, a `CaricamentoCapo::Importer` orchestrates the transactional replace. Two PORO query objects (`ClassificaQuery`, `ClassificaEditoreQuery`) feed a single read-only page. Auth is HTTP basic via env var. Deploy target: 37signals' Once.

**Tech Stack:** Rails 8.2.0.alpha (rails main), Ruby 3.4.7 (pinned in `mise.toml`), SQLite, Tailwind CSS v4, Minitest with fixtures, Propshaft, Importmap.

---

## Reference design

Read `docs/plans/2026-04-25-classifiche-capo-design.md` first. It contains the data model, parser/importer flow, and UI shape this plan implements.

## Source data

Sample real file (do not commit, read-only reference for fixture creation):
`/home/paolotax/Downloads/file adozioni 2025/ASCI819E_tax.txt`

Format: tab-separated, 23 columns, ~363 rows, no header. Columns:

| col | content                                                |
|-----|--------------------------------------------------------|
| 1   | codice materia (integer: 200, 300, ..., 1500)         |
| 2   | sigla editore (es. "ASCI")                             |
| 3   | anno (es. "2025")                                      |
| 4   | flag elimina #1 ("S" o vuoto) — semantica TBD          |
| 5   | alunni cl1                                             |
| 6   | alunni cl2                                             |
| 7   | alunni cl3                                             |
| 8   | alunni cl4                                             |
| 9   | alunni cl5                                             |
| 10  | flag elimina #2 ("S" o vuoto) — semantica TBD          |
| 11  | (campo non usato — saltare)                            |
| 12  | titolo                                                 |
| 13  | autore                                                 |
| 14  | nome editore esteso                                    |
| 15  | (campo non usato — saltare)                            |
| 16  | sezioni cl1                                            |
| 17  | sezioni cl2                                            |
| 18  | sezioni cl3                                            |
| 19  | sezioni cl4                                            |
| 20  | sezioni cl5                                            |
| 21  | (campo non usato — saltare)                            |
| 22  | ISBN                                                   |
| 23  | (campo non usato — saltare)                            |

Each input row produces up to 5 `RigaCapo` records (one per `classe`).

Skip a whole input row only if **all** alunni and **all** sezioni are zero.
Within a row, skip the per-classe record if both `alunni == 0` and `sezioni == 0`.

`flag_elimina_1` and `flag_elimina_2` are stored raw on `RigaCapo`. **Do not
filter on them** (semantics still unknown).

## Environment notes

- Working directory: `/home/paolotax/rails_2023/capo_app`
- Ruby is pinned via `mise.toml` to `3.4.7`. Run `eval "$(mise activate bash)"` once per shell, or use the explicit binstub `bin/rails` (which goes through bundle).
- Always run rails commands as `bin/rails ...` from the app root. Do **not** run `rails ...` (mise shim doesn't know which Ruby).
- Tests: `bin/rails test` for unit/integration, `bin/rails test:system` for system tests.
- Database: SQLite is the default. `bin/rails db:prepare` before first run.

## Skills to use during execution

- `superpowers:test-driven-development` — write failing test first, then minimal code.
- `superpowers:verification-before-completion` — run the failing test, see it fail; run again, see it pass; before claiming done.
- `superpowers-ruby:ruby-commit-message` — Conventional Commits.

---

## Task 1: Database setup + migrations

**Files:**
- Create: `db/migrate/<timestamp>_create_materie.rb`
- Create: `db/migrate/<timestamp>_create_caricamenti.rb`
- Create: `db/migrate/<timestamp>_create_righe_capo.rb`

**Step 1: Generate migrations**

```bash
bin/rails g migration CreateMaterie codice:integer:uniq nome:string ordine:integer
bin/rails g migration CreateCaricamenti filename:string caricato_il:datetime righe_count:integer
bin/rails g migration CreateRigheCapo \
  caricamento:references materia:references \
  classe:integer isbn:string titolo:string autore:string \
  editore_codice:string editore:string \
  sezioni:integer alunni:integer anno:string \
  scorrimento:boolean flag_elimina_1:string flag_elimina_2:string
```

**Step 2: Edit migration `CreateRigheCapo` to add composite index**

Open the generated `db/migrate/<timestamp>_create_righe_capo.rb` and add inside `create_table` block (or right after):

```ruby
add_index :righe_capo, [:classe, :materia_id]
```

The `caricamento:references` and `materia:references` already create indexes on those FKs.

**Step 3: Run migrations**

```bash
bin/rails db:prepare
```

Expected: 3 tables created, schema updated, no errors.

**Step 4: Commit**

```bash
git add db/migrate db/schema.rb
git commit -m "feat: add materie, caricamenti, righe_capo tables"
```

---

## Task 2: Models + associations

**Files:**
- Modify: `app/models/materia.rb`
- Modify: `app/models/caricamento.rb`
- Modify: `app/models/riga_capo.rb`
- Test: `test/models/materia_test.rb`, `test/models/caricamento_test.rb`, `test/models/riga_capo_test.rb`

**Step 1: Write failing test for `Materia` validation**

`test/models/materia_test.rb`:

```ruby
require "test_helper"

class MateriaTest < ActiveSupport::TestCase
  test "valid materia with codice nome ordine" do
    m = Materia.new(codice: 200, nome: "Sussidiario Linguaggi", ordine: 10)
    assert m.valid?
  end

  test "codice must be unique" do
    Materia.create!(codice: 200, nome: "X", ordine: 10)
    duplicate = Materia.new(codice: 200, nome: "Y", ordine: 11)
    refute duplicate.valid?
    assert_includes duplicate.errors[:codice], "has already been taken"
  end

  test "codice nome ordine all required" do
    refute Materia.new.valid?
  end
end
```

Delete the auto-generated fixture `test/fixtures/materie.yml` content (replace with empty file or `# empty`) so unique-constraint tests don't trip.

**Step 2: Run, see fail**

```bash
bin/rails test test/models/materia_test.rb
```

Expected: failures (no validations).

**Step 3: Implement `Materia`**

`app/models/materia.rb`:

```ruby
class Materia < ApplicationRecord
  has_many :righe_capo, class_name: "RigaCapo", dependent: :restrict_with_error

  validates :codice, presence: true, uniqueness: true
  validates :nome,   presence: true
  validates :ordine, presence: true

  scope :ordinate, -> { order(:ordine, :codice) }
end
```

**Step 4: Run, see pass**

```bash
bin/rails test test/models/materia_test.rb
```

Expected: 3 runs, 3 passes.

**Step 5: Implement `Caricamento` and `RigaCapo` (no tests yet — covered by importer tests in Task 4)**

`app/models/caricamento.rb`:

```ruby
class Caricamento < ApplicationRecord
  has_many :righe_capo, class_name: "RigaCapo", dependent: :delete_all

  validates :filename,    presence: true
  validates :caricato_il, presence: true
end
```

`app/models/riga_capo.rb`:

```ruby
class RigaCapo < ApplicationRecord
  self.table_name = "righe_capo"

  belongs_to :caricamento
  belongs_to :materia

  validates :classe,  presence: true, inclusion: { in: 1..5 }
  validates :sezioni, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :alunni,  presence: true, numericality: { greater_than_or_equal_to: 0 }
end
```

Empty out `test/fixtures/caricamenti.yml` and `test/fixtures/righe_capo.yml` (replace content with `# empty`) — they reference non-existent records and will break later tests if left.

**Step 6: Run all model tests**

```bash
bin/rails test test/models
```

Expected: passes (Materia tests + auto-generated Caricamento/RigaCapo placeholder tests, which only assert truthy).

**Step 7: Commit**

```bash
git add app/models test/fixtures test/models
git commit -m "feat: add Materia, Caricamento, RigaCapo models with validations"
```

---

## Task 3: Materie seed

**Files:**
- Modify: `db/seeds.rb`
- Test: `test/models/materia_seed_test.rb`

**Step 1: Edit `db/seeds.rb`**

Append (do not overwrite if there's other seed content — there isn't, the file is one comment):

```ruby
# Materie seed — codici noti dal file ASCII del capo
# Ordine: come vogliamo vederle nelle tab della pagina classifiche.
materie = [
  { codice: 1200, nome: "Libro della Prima",                ordine:  5 },
  { codice: 1300, nome: "Libro della Prima",                ordine:  6 },
  { codice:  200, nome: "Sussidiario Linguaggi",            ordine: 10 },
  { codice:  300, nome: "Sussidiario Discipline",           ordine: 20 },
  { codice: 1050, nome: "Sussidiario Discipline (Antrop)",  ordine: 21 },
  { codice: 1150, nome: "Sussidiario Discipline (Scient)",  ordine: 22 },
  { codice:  400, nome: "Religione",                        ordine: 30 },
  { codice:  500, nome: "Religione",                        ordine: 31 },
  { codice: 1500, nome: "Alternativa Religione",            ordine: 32 },
  { codice:  570, nome: "Inglese",                          ordine: 40 },
  { codice:  600, nome: "Inglese",                          ordine: 41 },
  { codice:  650, nome: "Inglese",                          ordine: 42 },
  { codice:  700, nome: "Francese",                         ordine: 50 },
  { codice:  750, nome: "Francese",                         ordine: 51 },
  { codice: 1000, nome: "Parascolastica umanistico",        ordine: 60 },
  { codice: 1100, nome: "Parascolastica scientifico",       ordine: 70 }
]

materie.each do |attrs|
  Materia.find_or_create_by!(codice: attrs[:codice]) do |m|
    m.nome   = attrs[:nome]
    m.ordine = attrs[:ordine]
  end
end
```

**Step 2: Run seed**

```bash
bin/rails db:seed
```

Expected: no error. `bin/rails runner "puts Materia.count"` → 16.

**Step 3: Commit**

```bash
git add db/seeds.rb
git commit -m "feat: seed materie with known codice→nome mapping"
```

---

## Task 4: Parser

**Files:**
- Create: `app/services/caricamento_capo/parser.rb`
- Test: `test/services/caricamento_capo/parser_test.rb`
- Create fixture: `test/fixtures/files/sample_capo.txt`

**Step 1: Build the fixture**

Pick 3 representative real lines from `/home/paolotax/Downloads/file adozioni 2025/ASCI819E_tax.txt` plus 1 fully-empty line. Read with:

```bash
head -3 "/home/paolotax/Downloads/file adozioni 2025/ASCI819E_tax.txt" > test/fixtures/files/sample_capo.txt
# inspect, then optionally append a synthetic all-zero line for the skip test
```

The fixture should have:
- at least one row with cl1 data
- at least one row with cl4 data
- at least one row with cl5 scorrimento data
- one row with all zeros (to assert it's skipped)

You may craft a synthetic minimal fixture instead (preserving 23 tab-separated columns):

```
200	ASCI	2025		100	0	0	120	0		.	TITOLO PRIMA	AUTORE A	EDITORE A		10	0	0	0	0	.	9788800000001	.
300	ASCI	2025		0	0	0	200	300	S	.	TITOLO QUARTA	AUTORE B	EDITORE B		0	0	0	20	30	.	9788800000002	.
1500	ASCI	2025		0	0	0	0	0		.	VUOTA	AUTORE	EDITORE		0	0	0	0	0	.	9788800000003	.
```

(Tabs between fields. The third row is fully empty — must be skipped.)

**Step 2: Write the failing test**

`test/services/caricamento_capo/parser_test.rb`:

```ruby
require "test_helper"

class CaricamentoCapo::ParserTest < ActiveSupport::TestCase
  setup do
    @path = Rails.root.join("test/fixtures/files/sample_capo.txt")
  end

  test "parses each row into a hash with header fields and per-class entries" do
    rows = CaricamentoCapo::Parser.new(@path).call
    assert_equal 2, rows.size, "fully-empty rows must be skipped"

    first = rows.first
    assert_equal 200,             first[:materia_codice]
    assert_equal "TITOLO PRIMA",  first[:titolo]
    assert_equal "9788800000001", first[:isbn]
    assert_equal "ASCI",          first[:editore_codice]
    assert_equal "EDITORE A",     first[:editore]
    assert_equal "2025",          first[:anno]

    cl1 = first[:righe].find { |r| r[:classe] == 1 }
    assert_equal({ classe: 1, sezioni: 10, alunni: 100 }, cl1)

    # Per-classe rows where both sezioni and alunni are 0 must be omitted.
    refute first[:righe].any? { |r| r[:classe] == 2 }
  end

  test "second row carries flag_elimina_2 raw" do
    rows = CaricamentoCapo::Parser.new(@path).call
    second = rows[1]
    assert_equal "S", second[:flag_elimina_2]
    assert_equal "",  second[:flag_elimina_1]
  end
end
```

**Step 3: Run, see fail**

```bash
bin/rails test test/services/caricamento_capo/parser_test.rb
```

Expected: error, `uninitialized constant CaricamentoCapo`.

**Step 4: Implement**

`app/services/caricamento_capo/parser.rb`:

```ruby
module CaricamentoCapo
  class Parser
    def initialize(path)
      @path = path
    end

    def call
      File.foreach(@path, chomp: true).filter_map { |line| parse_row(line) }
    end

    private

    def parse_row(line)
      cols = line.split("\t")
      return nil if cols.size < 23

      alunni  = cols[4..8].map(&:to_i)
      sezioni = cols[15..19].map(&:to_i)
      return nil if (alunni + sezioni).all?(&:zero?)

      righe = (1..5).filter_map do |classe|
        idx = classe - 1
        next if alunni[idx].zero? && sezioni[idx].zero?
        { classe: classe, sezioni: sezioni[idx], alunni: alunni[idx] }
      end

      {
        materia_codice:  cols[0].to_i,
        editore_codice:  cols[1],
        anno:            cols[2],
        flag_elimina_1:  cols[3],
        flag_elimina_2:  cols[9],
        titolo:          cols[11],
        autore:          cols[12],
        editore:         cols[13],
        isbn:            cols[21],
        righe:           righe
      }
    end
  end
end
```

**Step 5: Run, see pass**

```bash
bin/rails test test/services/caricamento_capo/parser_test.rb
```

Expected: 2 runs, 0 failures.

**Step 6: Commit**

```bash
git add app/services test/services test/fixtures/files/sample_capo.txt
git commit -m "feat: add parser for ASCII adozioni file"
```

---

## Task 5: Importer

**Files:**
- Create: `app/services/caricamento_capo/importer.rb`
- Test: `test/services/caricamento_capo/importer_test.rb`

**Step 1: Write the failing test**

`test/services/caricamento_capo/importer_test.rb`:

```ruby
require "test_helper"

class CaricamentoCapo::ImporterTest < ActiveSupport::TestCase
  setup do
    Materia.find_or_create_by!(codice: 200) { |m| m.nome = "Linguaggi"; m.ordine = 10 }
    Materia.find_or_create_by!(codice: 300) { |m| m.nome = "Discipline"; m.ordine = 20 }
    Materia.find_or_create_by!(codice: 1500) { |m| m.nome = "Alt"; m.ordine = 32 }

    @file = fixture_file_upload("sample_capo.txt", "text/plain")
  end

  test "imports rows from txt file in a single Caricamento" do
    assert_difference -> { Caricamento.count } => 1,
                      -> { RigaCapo.count }    => 3 do
      CaricamentoCapo::Importer.new(@file).call
    end

    car = Caricamento.last
    assert_equal "sample_capo.txt", car.filename
    assert_equal 3, car.righe_count
  end

  test "replaces previous caricamento on subsequent import" do
    CaricamentoCapo::Importer.new(@file).call
    first_id = Caricamento.last.id

    file2 = fixture_file_upload("sample_capo.txt", "text/plain")
    CaricamentoCapo::Importer.new(file2).call

    assert_equal 1, Caricamento.count
    refute Caricamento.exists?(first_id), "old caricamento must be deleted"
    assert_equal 3, RigaCapo.count
  end

  test "creates Materia placeholder when codice is unknown" do
    Materia.where(codice: 200).destroy_all
    CaricamentoCapo::Importer.new(@file).call
    placeholder = Materia.find_by(codice: 200)
    assert_not_nil placeholder
    assert_equal "Materia 200", placeholder.nome
    assert_equal 999,           placeholder.ordine
  end

  test "rolls back on parser error" do
    bad = Tempfile.new(["broken", ".txt"]).tap { |f| f.write("not enough cols\n"); f.rewind }
    upload = Rack::Test::UploadedFile.new(bad.path, "text/plain", original_filename: "broken.txt")
    assert_no_difference -> { Caricamento.count } do
      CaricamentoCapo::Importer.new(upload).call
    rescue StandardError
      # parser may raise or return [] — either way, no caricamento should remain
    end
  end
end
```

**Step 2: Run, see fail**

```bash
bin/rails test test/services/caricamento_capo/importer_test.rb
```

Expected: error `uninitialized constant CaricamentoCapo::Importer`.

**Step 3: Implement**

`app/services/caricamento_capo/importer.rb`:

```ruby
module CaricamentoCapo
  class Importer
    def initialize(uploaded_file)
      @uploaded = uploaded_file
    end

    def call
      stored_path = persist_to_tmp(@uploaded)
      ActiveRecord::Base.transaction do
        caricamento = Caricamento.create!(
          filename:    @uploaded.original_filename,
          caricato_il: Time.current
        )

        rows  = Parser.new(stored_path).call
        cache = materia_cache_for(rows)
        attrs = build_riga_attrs(rows, caricamento, cache)

        RigaCapo.insert_all!(attrs) if attrs.any?

        Caricamento.where.not(id: caricamento.id).destroy_all
        caricamento.update!(righe_count: attrs.size)
        caricamento
      end
    end

    private

    def persist_to_tmp(uploaded)
      dir = Rails.root.join("tmp/uploads")
      FileUtils.mkdir_p(dir)
      path = dir.join("#{Time.current.to_i}_#{uploaded.original_filename}")
      File.binwrite(path, uploaded.read)
      path
    end

    def materia_cache_for(rows)
      codici = rows.map { |r| r[:materia_codice] }.uniq
      cache  = Materia.where(codice: codici).index_by(&:codice)
      codici.each do |codice|
        next if cache[codice]
        cache[codice] = Materia.create!(
          codice: codice,
          nome:   "Materia #{codice}",
          ordine: 999
        )
        Rails.logger.warn("[CaricamentoCapo] codice materia sconosciuto: #{codice} (creato placeholder)")
      end
      cache
    end

    def build_riga_attrs(rows, caricamento, cache)
      now = Time.current
      rows.flat_map do |row|
        materia_id = cache.fetch(row[:materia_codice]).id
        row[:righe].map do |sub|
          {
            caricamento_id:   caricamento.id,
            materia_id:       materia_id,
            classe:           sub[:classe],
            isbn:             row[:isbn],
            titolo:           row[:titolo],
            autore:           row[:autore],
            editore_codice:   row[:editore_codice],
            editore:          row[:editore],
            sezioni:          sub[:sezioni],
            alunni:           sub[:alunni],
            anno:             row[:anno],
            scorrimento:      sub[:classe] == 5,
            flag_elimina_1:   row[:flag_elimina_1],
            flag_elimina_2:   row[:flag_elimina_2],
            created_at:       now,
            updated_at:       now
          }
        end
      end
    end
  end
end
```

**Step 4: Run, see pass**

```bash
bin/rails test test/services/caricamento_capo/importer_test.rb
```

Expected: 4 runs, 0 failures.

**Step 5: Commit**

```bash
git add app/services/caricamento_capo/importer.rb test/services/caricamento_capo/importer_test.rb
git commit -m "feat: add importer with transactional replace strategy"
```

---

## Task 6: ClassificaQuery + ClassificaEditoreQuery

**Files:**
- Create: `app/queries/classifica_query.rb`
- Create: `app/queries/classifica_editore_query.rb`
- Test: `test/queries/classifica_query_test.rb`

**Step 1: Write the failing test**

`test/queries/classifica_query_test.rb`:

```ruby
require "test_helper"

class ClassificaQueryTest < ActiveSupport::TestCase
  setup do
    @materia = Materia.create!(codice: 200, nome: "Test", ordine: 10)
    @car     = Caricamento.create!(filename: "x", caricato_il: Time.current)

    [
      { isbn: "1", titolo: "A", autore: "a1", editore: "EdA", sezioni: 100, alunni: 1700 },
      { isbn: "2", titolo: "B", autore: "a2", editore: "EdB", sezioni:  50, alunni:  850 },
      { isbn: "3", titolo: "C", autore: "a3", editore: "EdA", sezioni:  25, alunni:  425 }
    ].each do |attrs|
      RigaCapo.create!(
        caricamento: @car, materia: @materia, classe: 4,
        editore_codice: "EDA", scorrimento: false, anno: "2025",
        **attrs
      )
    end
  end

  test "ranks by sezioni descending and computes quota%" do
    rows = ClassificaQuery.new(classe: 4, materia: @materia).righe

    assert_equal %w[A B C], rows.map { |r| r["titolo"] }
    assert_equal [100, 50, 25], rows.map { |r| r["sezioni"] }

    quote = rows.map { |r| r["quota"] }
    assert_equal 100.0, quote.sum.round(1)
    assert_equal 57.1, quote.first
  end

  test "excludes rows where sezioni == 0" do
    RigaCapo.create!(caricamento: @car, materia: @materia, classe: 4,
                     isbn: "4", titolo: "D", autore: "a", editore: "EdC",
                     sezioni: 0, alunni: 0,
                     editore_codice: "EDC", scorrimento: false, anno: "2025")
    rows = ClassificaQuery.new(classe: 4, materia: @materia).righe
    assert_equal 3, rows.size
  end
end
```

**Step 2: Run, see fail**

```bash
bin/rails test test/queries/classifica_query_test.rb
```

Expected: `uninitialized constant ClassificaQuery`.

**Step 3: Implement `ClassificaQuery`**

`app/queries/classifica_query.rb`:

```ruby
class ClassificaQuery
  def initialize(classe:, materia:)
    @classe  = classe
    @materia = materia
  end

  def righe
    rows = base.to_a
    tot  = rows.sum { |r| r.sezioni.to_i }.to_f
    return [] if tot.zero?

    rows.map do |r|
      r.attributes.merge("quota" => (r.sezioni.to_f / tot * 100).round(1))
    end
  end

  private

  def base
    RigaCapo
      .where(classe: @classe, materia: @materia)
      .where("sezioni > 0")
      .group(:isbn, :titolo, :autore, :editore)
      .select("isbn, titolo, autore, editore,
               SUM(sezioni) AS sezioni,
               SUM(alunni)  AS alunni")
      .order(Arel.sql("SUM(sezioni) DESC"))
  end
end
```

**Step 4: Run, see pass**

```bash
bin/rails test test/queries/classifica_query_test.rb
```

Expected: 2 runs, 0 failures.

**Step 5: Implement `ClassificaEditoreQuery`** (same fixtures will exercise it via Task 7's view; minimal test below)

`app/queries/classifica_editore_query.rb`:

```ruby
class ClassificaEditoreQuery
  def initialize(classe:, materia:)
    @classe  = classe
    @materia = materia
  end

  def righe
    rows = base.to_a
    tot  = rows.sum { |r| r.sezioni.to_i }.to_f
    return [] if tot.zero?

    rows.map do |r|
      r.attributes.merge("quota" => (r.sezioni.to_f / tot * 100).round(1))
    end
  end

  private

  def base
    RigaCapo
      .where(classe: @classe, materia: @materia)
      .where("sezioni > 0")
      .group(:editore)
      .select("editore,
               SUM(sezioni)        AS sezioni,
               SUM(alunni)         AS alunni,
               COUNT(DISTINCT isbn) AS titoli")
      .order(Arel.sql("SUM(sezioni) DESC"))
  end
end
```

Append to `test/queries/classifica_query_test.rb`:

```ruby
class ClassificaEditoreQueryTest < ActiveSupport::TestCase
  setup do
    @materia = Materia.create!(codice: 300, nome: "Test", ordine: 20)
    @car     = Caricamento.create!(filename: "x", caricato_il: Time.current)
    [
      { isbn: "1", titolo: "A", autore: "a", editore: "EdA", sezioni: 100, alunni: 1700 },
      { isbn: "2", titolo: "B", autore: "a", editore: "EdA", sezioni:  50, alunni:  850 },
      { isbn: "3", titolo: "C", autore: "a", editore: "EdB", sezioni:  50, alunni:  850 }
    ].each do |attrs|
      RigaCapo.create!(caricamento: @car, materia: @materia, classe: 4,
                       editore_codice: "X", scorrimento: false, anno: "2025", **attrs)
    end
  end

  test "aggregates per editore with titoli count" do
    rows = ClassificaEditoreQuery.new(classe: 4, materia: @materia).righe
    eda  = rows.find { |r| r["editore"] == "EdA" }
    assert_equal 150, eda["sezioni"]
    assert_equal 2,   eda["titoli"]
    assert_equal 75.0, eda["quota"]
  end
end
```

**Step 6: Run, see pass**

```bash
bin/rails test test/queries
```

Expected: 3 runs, 0 failures.

**Step 7: Commit**

```bash
git add app/queries test/queries
git commit -m "feat: add ClassificaQuery and ClassificaEditoreQuery"
```

---

## Task 7: Caricamenti controller + form

**Files:**
- Create: `app/controllers/caricamenti_controller.rb`
- Create: `app/views/caricamenti/new.html.erb`
- Modify: `config/routes.rb`
- Test: `test/controllers/caricamenti_controller_test.rb`

**Step 1: Routes**

`config/routes.rb`:

```ruby
Rails.application.routes.draw do
  resources :caricamenti, only: %i[new create destroy]
  resource  :classifica,   only: :show
  root "classifiche#show"
end
```

(`ClassifichController` doesn't exist yet — that's Task 8. The routes file is fine to declare them now.)

**Step 2: Write failing controller test**

`test/controllers/caricamenti_controller_test.rb`:

```ruby
require "test_helper"

class CaricamentiControllerTest < ActionDispatch::IntegrationTest
  setup do
    Materia.find_or_create_by!(codice: 200) { |m| m.nome = "L"; m.ordine = 10 }
    Materia.find_or_create_by!(codice: 300) { |m| m.nome = "D"; m.ordine = 20 }
    Materia.find_or_create_by!(codice: 1500) { |m| m.nome = "A"; m.ordine = 32 }
  end

  test "GET new renders upload form" do
    get new_caricamento_path
    assert_response :success
    assert_select "form input[type=file][name='file']"
  end

  test "POST create imports file and redirects to classifica" do
    file = fixture_file_upload("sample_capo.txt", "text/plain")
    assert_difference -> { RigaCapo.count }, 3 do
      post caricamenti_path, params: { file: file }
    end
    assert_redirected_to classifica_path
    follow_redirect!
    assert_response :success
  end

  test "POST create with no file shows error" do
    post caricamenti_path
    assert_response :unprocessable_content
    assert_select ".error", /file/i
  end
end
```

**Step 3: Run, see fail**

```bash
bin/rails test test/controllers/caricamenti_controller_test.rb
```

Expected: route helper missing or controller missing.

**Step 4: Implement controller**

`app/controllers/caricamenti_controller.rb`:

```ruby
class CaricamentiController < ApplicationController
  def new
  end

  def create
    if params[:file].blank?
      @error = "Seleziona un file."
      return render :new, status: :unprocessable_content
    end

    CaricamentoCapo::Importer.new(params[:file]).call
    redirect_to classifica_path, notice: "File caricato. Classifiche aggiornate."
  rescue StandardError => e
    Rails.logger.error("[Caricamento] #{e.class}: #{e.message}")
    @error = "Errore nell'import: #{e.message}"
    render :new, status: :unprocessable_content
  end

  def destroy
    Caricamento.find(params[:id]).destroy
    redirect_to new_caricamento_path, notice: "Snapshot rimossa."
  end
end
```

**Step 5: Implement view**

`app/views/caricamenti/new.html.erb`:

```erb
<div class="mx-auto max-w-xl p-8">
  <h1 class="text-2xl font-bold mb-6">Carica file ASCII</h1>

  <% if @error.present? %>
    <p class="error mb-4 text-red-600"><%= @error %></p>
  <% end %>

  <%= form_with url: caricamenti_path, multipart: true, local: true, class: "space-y-4" do %>
    <input type="file" name="file" accept=".txt" required class="block">
    <button type="submit" class="bg-black text-white px-4 py-2 rounded">Carica</button>
  <% end %>

  <% if (last = Caricamento.order(:caricato_il).last) %>
    <p class="mt-8 text-sm text-gray-600">
      Ultimo caricamento: <%= last.filename %> — <%= l last.caricato_il, format: :short %>
      (<%= last.righe_count %> righe)
    </p>
  <% end %>
</div>
```

**Step 6: Run, see pass** (third test still fails because `ClassifichController` doesn't exist — that's expected; comment it out or skip until Task 8)

For now, comment out the assertion that follows the redirect:

```ruby
test "POST create imports file and redirects to classifica" do
  file = fixture_file_upload("sample_capo.txt", "text/plain")
  assert_difference -> { RigaCapo.count }, 3 do
    post caricamenti_path, params: { file: file }
  end
  assert_redirected_to classifica_path
end
```

```bash
bin/rails test test/controllers/caricamenti_controller_test.rb
```

Expected: 3 runs, 0 failures.

**Step 7: Commit**

```bash
git add app/controllers app/views config/routes.rb test/controllers
git commit -m "feat: add caricamenti controller and upload form"
```

---

## Task 8: Classifiche page

**Files:**
- Create: `app/controllers/classifiche_controller.rb`
- Create: `app/views/classifiche/show.html.erb`
- Create: `app/views/classifiche/_classifica.html.erb`
- Create: `app/views/classifiche/_aggregato_editori.html.erb`
- Test: `test/controllers/classifiche_controller_test.rb`

**Step 1: Write failing controller test**

`test/controllers/classifiche_controller_test.rb`:

```ruby
require "test_helper"

class ClassificheControllerTest < ActionDispatch::IntegrationTest
  test "GET show with empty DB redirects to upload" do
    RigaCapo.delete_all
    Caricamento.delete_all
    get classifica_path
    assert_redirected_to new_caricamento_path
  end

  test "GET show renders classifiche with data" do
    Materia.find_or_create_by!(codice: 200) { |m| m.nome = "Linguaggi"; m.ordine = 10 }
    car = Caricamento.create!(filename: "x", caricato_il: Time.current, righe_count: 1)
    RigaCapo.create!(caricamento: car, materia: Materia.find_by(codice: 200),
                     classe: 4, isbn: "1", titolo: "FOO", autore: "a", editore: "EdX",
                     sezioni: 10, alunni: 170, scorrimento: false, anno: "2025",
                     editore_codice: "EX", flag_elimina_1: "", flag_elimina_2: "")

    get classifica_path
    assert_response :success
    assert_select "h2", /Classe 4/
    assert_select "td", /FOO/
  end
end
```

**Step 2: Run, see fail**

```bash
bin/rails test test/controllers/classifiche_controller_test.rb
```

**Step 3: Implement controller**

`app/controllers/classifiche_controller.rb`:

```ruby
class ClassificheController < ApplicationController
  CLASSI = [1, 4].freeze

  def show
    return redirect_to(new_caricamento_path) if RigaCapo.none?

    @ultimo_caricamento = Caricamento.order(:caricato_il).last
    @classifiche = CLASSI.index_with do |classe|
      Materia.ordinate
             .joins(:righe_capo)
             .where(righe_capo: { classe: classe })
             .where("righe_capo.sezioni > 0")
             .distinct
    end
  end
end
```

**Step 4: Implement views**

`app/views/classifiche/show.html.erb`:

```erb
<div class="max-w-7xl mx-auto p-6 space-y-12">
  <header class="flex items-center justify-between">
    <h1 class="text-3xl font-bold">Classifiche</h1>
    <div class="text-sm text-gray-600">
      <%= @ultimo_caricamento.filename %> — <%= l @ultimo_caricamento.caricato_il, format: :short %>
      <%= link_to "Sostituisci file", new_caricamento_path, class: "ml-3 underline" %>
    </div>
  </header>

  <% @classifiche.each do |classe, materie| %>
    <section>
      <h2 class="text-2xl font-semibold mb-4">Classe <%= classe %></h2>

      <% materie.each do |materia| %>
        <%= render "classifica", classe: classe, materia: materia %>
      <% end %>
    </section>
  <% end %>
</div>
```

`app/views/classifiche/_classifica.html.erb`:

```erb
<details class="mb-6 border rounded p-4" open>
  <summary class="font-medium text-lg cursor-pointer">
    <%= materia.nome %> <span class="text-gray-500">(<%= materia.codice %>)</span>
  </summary>

  <% righe = ClassificaQuery.new(classe: classe, materia: materia).righe %>

  <table class="w-full mt-4 text-sm">
    <thead>
      <tr class="text-left border-b">
        <th class="py-1 pr-3">#</th>
        <th class="py-1 pr-3">Titolo</th>
        <th class="py-1 pr-3">Autore</th>
        <th class="py-1 pr-3">Editore</th>
        <th class="py-1 pr-3 text-right">Sezioni</th>
        <th class="py-1 pr-3 text-right">Alunni</th>
        <th class="py-1 pr-3 text-right">Quota %</th>
      </tr>
    </thead>
    <tbody>
      <% righe.each_with_index do |r, i| %>
        <tr class="border-b">
          <td class="py-1 pr-3"><%= i + 1 %></td>
          <td class="py-1 pr-3"><%= r["titolo"] %></td>
          <td class="py-1 pr-3"><%= r["autore"] %></td>
          <td class="py-1 pr-3"><%= r["editore"] %></td>
          <td class="py-1 pr-3 text-right"><%= number_with_delimiter r["sezioni"] %></td>
          <td class="py-1 pr-3 text-right"><%= number_with_delimiter r["alunni"] %></td>
          <td class="py-1 pr-3 text-right"><%= number_with_precision r["quota"], precision: 1 %></td>
        </tr>
      <% end %>
    </tbody>
  </table>

  <%= render "aggregato_editori", classe: classe, materia: materia %>
</details>
```

`app/views/classifiche/_aggregato_editori.html.erb`:

```erb
<% editori = ClassificaEditoreQuery.new(classe: classe, materia: materia).righe %>
<% if editori.any? %>
  <h4 class="mt-6 mb-2 text-sm font-semibold text-gray-700">Aggregato per editore</h4>
  <table class="w-full text-xs">
    <thead>
      <tr class="text-left border-b">
        <th class="py-1 pr-3">Editore</th>
        <th class="py-1 pr-3 text-right">Titoli</th>
        <th class="py-1 pr-3 text-right">Sezioni</th>
        <th class="py-1 pr-3 text-right">Alunni</th>
        <th class="py-1 pr-3 text-right">Quota %</th>
      </tr>
    </thead>
    <tbody>
      <% editori.each do |r| %>
        <tr>
          <td class="py-1 pr-3"><%= r["editore"] %></td>
          <td class="py-1 pr-3 text-right"><%= r["titoli"] %></td>
          <td class="py-1 pr-3 text-right"><%= number_with_delimiter r["sezioni"] %></td>
          <td class="py-1 pr-3 text-right"><%= number_with_delimiter r["alunni"] %></td>
          <td class="py-1 pr-3 text-right"><%= number_with_precision r["quota"], precision: 1 %></td>
        </tr>
      <% end %>
    </tbody>
  </table>
<% end %>
```

**Step 5: Run, see pass**

```bash
bin/rails test test/controllers/classifiche_controller_test.rb
```

Expected: 2 runs, 0 failures.

**Step 6: Re-enable the redirect-follow assertion in `caricamenti_controller_test.rb`**

Restore the `follow_redirect!` and `assert_response :success` lines in the second test from Task 7 — they should now pass.

**Step 7: Run full test suite**

```bash
bin/rails test
```

Expected: all green.

**Step 8: Commit**

```bash
git add app/controllers/classifiche_controller.rb app/views/classifiche test/controllers/classifiche_controller_test.rb test/controllers/caricamenti_controller_test.rb
git commit -m "feat: add classifiche page with per-materia rankings and editore rollup"
```

---

## Task 9: HTTP basic auth

**Files:**
- Modify: `app/controllers/application_controller.rb`
- Modify: `.env` (already exists from `rails new`) — document in README
- Modify: `test/test_helper.rb`

**Step 1: Add auth to `ApplicationController`**

`app/controllers/application_controller.rb`:

```ruby
class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  http_basic_authenticate_with(
    name:     ENV.fetch("APP_USERNAME", "capo"),
    password: ENV.fetch("APP_PASSWORD", "capo"),
    if:       -> { Rails.env.production? }
  )
end
```

(Disabled in development/test by `if:` guard so existing tests keep passing without auth.)

**Step 2: Run full suite**

```bash
bin/rails test
```

Expected: still all green.

**Step 3: Document in README**

Append to `README.md`:

```markdown

## Auth

In production, set `APP_USERNAME` and `APP_PASSWORD` env vars. HTTP basic auth gates the entire app. In development/test no auth is required.
```

**Step 4: Commit**

```bash
git add app/controllers/application_controller.rb README.md
git commit -m "feat: gate app with HTTP basic auth in production"
```

---

## Task 10: System test (smoke)

**Files:**
- Create: `test/system/upload_and_classifiche_test.rb`

**Step 1: Write the test**

```ruby
require "application_system_test_case"

class UploadAndClassificheTest < ApplicationSystemTestCase
  setup do
    Materia.find_or_create_by!(codice: 200)  { |m| m.nome = "Linguaggi"; m.ordine = 10 }
    Materia.find_or_create_by!(codice: 300)  { |m| m.nome = "Discipline"; m.ordine = 20 }
    Materia.find_or_create_by!(codice: 1500) { |m| m.nome = "Alt";        m.ordine = 32 }
  end

  test "user uploads file and sees classifiche" do
    visit root_path
    # Empty DB → redirected to upload
    assert_current_path new_caricamento_path

    attach_file "file", Rails.root.join("test/fixtures/files/sample_capo.txt")
    click_button "Carica"

    assert_current_path classifica_path
    assert_text "Classe 4"
    assert_text "TITOLO QUARTA"
  end
end
```

**Step 2: Run**

```bash
bin/rails test:system
```

Expected: pass. (Requires Selenium/Chrome — already in default Gemfile.)

**Step 3: Commit**

```bash
git add test/system/upload_and_classifiche_test.rb
git commit -m "test: add system test for upload→classifiche flow"
```

---

## Task 11: README + deploy notes

**Files:**
- Modify: `README.md`

**Step 1: Replace README with project description**

```markdown
# capo_app

Single-user Rails app for the boss: ingest a tab-separated ASCII file of
national textbook adoption aggregates and produce market-share rankings by
class × subject (materia).

## Local development

```bash
bin/setup
bin/dev
```

Open http://localhost:3000 — empty DB redirects to `/caricamenti/new`.

Sample fixture: `test/fixtures/files/sample_capo.txt`.

## Tests

```bash
bin/rails test
bin/rails test:system
```

## Production / Once deploy

Set env vars:

- `APP_USERNAME` — HTTP basic auth user
- `APP_PASSWORD` — HTTP basic auth password
- `RAILS_MASTER_KEY` — from `config/master.key`

Then `kamal deploy` (or whatever Once uses).

## Data format

See `docs/plans/2026-04-25-classifiche-capo-design.md` and
`docs/plans/2026-04-25-classifiche-capo-plan.md` for the column-by-column
contract of the input file.
```

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: README with setup, tests, deploy"
```

---

## Verification checklist

Before declaring done, ensure:

- [ ] `bin/rails test` — green
- [ ] `bin/rails test:system` — green
- [ ] `bin/rails db:reset && bin/rails db:seed` — works, 16 materie present
- [ ] `bin/dev` runs without error
- [ ] Upload of real file `/home/paolotax/Downloads/file adozioni 2025/ASCI819E_tax.txt` (manually, in dev) produces > 1.000 `RigaCapo` and renders without errors
- [ ] `git log --oneline` shows ~11 commits, one per Task

---

## Out of scope (do NOT implement)

- Multi-snapshot/versioned imports (replace strategy is final).
- CSV/PDF export.
- Avo or admin panel.
- Editor normalization or codice editore mapping.
- Detailed per-libro pages.
- Filters/search beyond the rankings page.

If a need surfaces during implementation, log it in `docs/plans/` as a
follow-up note rather than expanding scope.

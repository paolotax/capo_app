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

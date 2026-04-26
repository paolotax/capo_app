# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

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

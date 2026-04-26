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

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

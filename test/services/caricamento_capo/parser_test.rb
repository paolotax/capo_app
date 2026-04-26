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

    refute first[:righe].any? { |r| r[:classe] == 2 }
  end

  test "second row carries flag_elimina_2 raw" do
    rows = CaricamentoCapo::Parser.new(@path).call
    second = rows[1]
    assert_equal "S", second[:flag_elimina_2]
    assert_equal "",  second[:flag_elimina_1]
  end
end

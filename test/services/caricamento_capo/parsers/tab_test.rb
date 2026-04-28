require "test_helper"

class CaricamentoCapo::Parsers::TabTest < ActiveSupport::TestCase
  setup do
    @path = Rails.root.join("test/fixtures/files/sample_capo.txt")
    @rows = CaricamentoCapo::Parsers::Tab.new(@path).call
  end

  test "skips fully-empty rows" do
    assert_equal 2, @rows.size
  end

  test "extracts header fields and per-class entries on first row" do
    first = @rows.first
    assert_equal 200,             first[:materia_codice]
    assert_equal "TITOLO PRIMA",  first[:titolo]
    assert_equal "9788800000001", first[:isbn]
    assert_equal "ASCI",          first[:editore_codice]
    assert_equal "EDITORE A",     first[:editore]
    assert_equal "2025",          first[:anno]

    assert_equal({ classe: 1, sezioni: 10, alunni: 100 },
                 first[:righe].find { |r| r[:classe] == 1 })
    refute first[:righe].any? { |r| r[:classe] == 2 }
  end

  test "captures the post-anno flag in flag_a (col 3)" do
    assert_equal "S", @rows.first[:flag_a]
    assert_equal "",  @rows.first[:flag_b]
  end

  test "captures the post-editore flag in flag_d (col 14)" do
    second = @rows[1]
    assert_equal "",  second[:flag_a]
    assert_equal "S", second[:flag_d]
  end

  test "captures tipo_libro from col 10" do
    assert_equal "2", @rows.first[:tipo_libro]
    assert_equal "2", @rows[1][:tipo_libro]
  end
end

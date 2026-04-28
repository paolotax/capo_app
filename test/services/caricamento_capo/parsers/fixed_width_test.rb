require "test_helper"

class CaricamentoCapo::Parsers::FixedWidthTest < ActiveSupport::TestCase
  setup do
    @path = Rails.root.join("test/fixtures/files/sample_capo_fixed.txt")
    @rows = CaricamentoCapo::Parsers::FixedWidth.new(@path).call
  end

  test "parses every row of the fixture (none are fully empty)" do
    assert_equal 6, @rows.size
  end

  test "extracts header fields from a typical row (BOTTEGA DELLE STORIE)" do
    first = @rows.first
    assert_equal 200,                         first[:materia_codice]
    assert_equal "4",                         first[:editore_codice]
    assert_equal "2025",                      first[:anno]
    assert_equal "BOTTEGA DELLE STORIE (LA)", first[:titolo]
    assert_equal "BRAMATI EMANUELA",          first[:autore]
    assert_equal "A. MONDADORI SCUOLA",       first[:editore]
    assert_equal "9791220410731",             first[:isbn]
  end

  test "produces one classe entry per non-zero alunni-or-sezioni column" do
    first = @rows.first

    cl4 = first[:righe].find { |r| r[:classe] == 4 }
    cl5 = first[:righe].find { |r| r[:classe] == 5 }
    assert_equal({ classe: 4, sezioni: 3204, alunni: 59041 }, cl4)
    assert_equal({ classe: 5, sezioni: 15,   alunni: 258 },   cl5)
    refute first[:righe].any? { |r| [1, 2, 3].include?(r[:classe]) }
  end

  test "row with data in every class produces 5 classe entries (UN CIELO A COLORI)" do
    cielo = @rows.find { |r| r[:titolo] == "UN CIELO A COLORI CL. 1-2-3" }

    assert_equal [1, 2, 3, 4, 5], cielo[:righe].map { |r| r[:classe] }
    cl1 = cielo[:righe].find { |r| r[:classe] == 1 }
    assert_equal({ classe: 1, sezioni: 4537, alunni: 76833 }, cl1)
  end

  test "decodes Windows-1252 accents into UTF-8 (TANTE VOCI titolo)" do
    tante = @rows.find { |r| r[:titolo].start_with?("TANTE VOCI") }

    assert_equal "TANTE VOCI 4 (MODALITÀ DIGITALE C)", tante[:titolo]
    assert tante[:titolo].valid_encoding?
    assert_equal Encoding::UTF_8, tante[:titolo].encoding
  end

  test "captures pos-18 flag in flag_a (BOTTEGA)" do
    bottega = @rows.find { |r| r[:titolo] == "BOTTEGA DELLE STORIE (LA)" }
    assert_equal "S", bottega[:flag_a]
    assert_equal "",  bottega[:flag_b]
    assert_equal "",  bottega[:flag_d]
  end

  test "captures pos-19 flag in flag_b (NUOVO VIVA)" do
    nuovo = @rows.find { |r| r[:titolo] == "NUOVO VIVA LEGGERE CL. 4" }
    assert_equal "",  nuovo[:flag_a]
    assert_equal "S", nuovo[:flag_b]
    assert_equal "",  nuovo[:flag_d]
  end

  test "captures pos-208 flag in flag_d (AMICA PAROLA)" do
    amica = @rows.find { |r| r[:titolo] == "AMICA PAROLA CL. 4" }
    assert_equal "",  amica[:flag_a]
    assert_equal "",  amica[:flag_b]
    assert_equal "S", amica[:flag_d]
  end

  test "captures tipo_libro from pos 71" do
    bottega = @rows.find { |r| r[:titolo] == "BOTTEGA DELLE STORIE (LA)" }
    assert_equal "2", bottega[:tipo_libro]

    cielo = @rows.find { |r| r[:titolo] == "UN CIELO A COLORI CL. 1-2-3" }
    assert_equal "1", cielo[:tipo_libro]

    supertobia = @rows.find { |r| r[:titolo].start_with?("SUPERTOBIA") }
    assert_equal "3", supertobia[:tipo_libro]
  end

  test "skips lines with unexpected length" do
    Tempfile.create(["broken_fixed", ".txt"]) do |f|
      f.binmode
      f.write("too short\r\n")
      f.write(File.binread(@path).lines.first)
      f.flush

      rows = CaricamentoCapo::Parsers::FixedWidth.new(f.path).call
      assert_equal 1, rows.size
    end
  end
end

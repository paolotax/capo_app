require "test_helper"

class CaricamentoCapo::ImporterTest < ActiveSupport::TestCase
  setup do
    Materia.find_or_create_by!(codice: 200)  { |m| m.nome = "Linguaggi";  m.ordine = 10 }
    Materia.find_or_create_by!(codice: 300)  { |m| m.nome = "Discipline"; m.ordine = 20 }
    Materia.find_or_create_by!(codice: 1500) { |m| m.nome = "Alt";        m.ordine = 32 }

    @file = Rack::Test::UploadedFile.new(
      Rails.root.join("test/fixtures/files/sample_capo.txt"),
      "text/plain"
    )
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

    file2 = Rack::Test::UploadedFile.new(
      Rails.root.join("test/fixtures/files/sample_capo.txt"),
      "text/plain"
    )
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

  test "imports fixed-width files end-to-end" do
    fixed = Rack::Test::UploadedFile.new(
      Rails.root.join("test/fixtures/files/sample_capo_fixed.txt"),
      "text/plain"
    )

    assert_difference -> { Caricamento.count } => 1,
                      -> { RigaCapo.count }    => 17 do
      CaricamentoCapo::Importer.new(fixed).call
    end

    car = Caricamento.last
    assert_equal "sample_capo_fixed.txt", car.filename
    assert_equal 17, car.righe_count

    bottega = RigaCapo.find_by(isbn: "9791220410731", classe: 4)
    assert_equal "BOTTEGA DELLE STORIE (LA)", bottega.titolo
    assert_equal 59041, bottega.alunni
    assert_equal 3204,  bottega.sezioni

    tante = RigaCapo.find_by(isbn: "9788861619999", classe: 4)
    assert_equal "TANTE VOCI 4 (MODALITÀ DIGITALE C)", tante.titolo
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

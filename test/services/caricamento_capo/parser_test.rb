require "test_helper"

class CaricamentoCapo::ParserTest < ActiveSupport::TestCase
  test "routes tab-separated files through Parsers::Tab" do
    path = Rails.root.join("test/fixtures/files/sample_capo.txt")
    rows = CaricamentoCapo::Parser.new(path).call

    assert_equal 2, rows.size
    assert_equal "TITOLO PRIMA",  rows.first[:titolo]
    assert_equal "9788800000001", rows.first[:isbn]
  end

  test "routes fixed-width files through Parsers::FixedWidth" do
    path = Rails.root.join("test/fixtures/files/sample_capo_fixed.txt")
    rows = CaricamentoCapo::Parser.new(path).call

    assert_equal 6, rows.size
    bottega = rows.find { |r| r[:isbn] == "9791220410731" }
    assert_equal "BOTTEGA DELLE STORIE (LA)", bottega[:titolo]
  end
end

require "test_helper"

class CaricamentoCapo::DetectorTest < ActiveSupport::TestCase
  test "detects fixed-width format" do
    path = Rails.root.join("test/fixtures/files/sample_capo_fixed.txt")
    assert_equal :fixed_width, CaricamentoCapo::Detector.call(path)
  end

  test "detects tab-separated format" do
    path = Rails.root.join("test/fixtures/files/sample_capo.txt")
    assert_equal :tab, CaricamentoCapo::Detector.call(path)
  end

  test "raises on unknown format" do
    Tempfile.create(["unknown", ".txt"]) do |f|
      f.binmode
      f.write("just plain text without tabs or fixed-width markers\n")
      f.flush
      assert_raises(CaricamentoCapo::Detector::UnknownFormatError) do
        CaricamentoCapo::Detector.call(f.path)
      end
    end
  end

  test "raises on empty file" do
    Tempfile.create(["empty", ".txt"]) do |f|
      assert_raises(CaricamentoCapo::Detector::UnknownFormatError) do
        CaricamentoCapo::Detector.call(f.path)
      end
    end
  end
end

require "application_system_test_case"

class UploadAndClassificheTest < ApplicationSystemTestCase
  setup do
    Materia.find_or_create_by!(codice: 200)  { |m| m.nome = "Linguaggi";  m.ordine = 10 }
    Materia.find_or_create_by!(codice: 300)  { |m| m.nome = "Discipline"; m.ordine = 20 }
    Materia.find_or_create_by!(codice: 1500) { |m| m.nome = "Alt";        m.ordine = 32 }
  end

  test "user uploads file and sees classifiche" do
    visit root_path
    assert_current_path new_caricamento_path

    attach_file "file", Rails.root.join("test/fixtures/files/sample_capo.txt")
    click_button "Carica"

    assert_current_path classifica_path
    assert_text "Classe 4"
    assert_text "TITOLO QUARTA"
  end
end

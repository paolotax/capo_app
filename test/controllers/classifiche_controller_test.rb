require "test_helper"

class ClassificheControllerTest < ActionDispatch::IntegrationTest
  test "GET show with empty DB redirects to upload" do
    RigaCapo.delete_all
    Caricamento.delete_all
    get classifica_path
    assert_redirected_to new_caricamento_path
  end

  test "GET show renders classifiche with data" do
    Materia.find_or_create_by!(codice: 200) { |m| m.nome = "Linguaggi"; m.ordine = 10 }
    car = Caricamento.create!(filename: "x", caricato_il: Time.current, righe_count: 1)
    RigaCapo.create!(caricamento: car, materia: Materia.find_by(codice: 200),
                     classe: 4, isbn: "1", titolo: "FOO", autore: "a", editore: "EdX",
                     sezioni: 10, alunni: 170, scorrimento: false, anno: "2025",
                     editore_codice: "EX", flag_elimina_1: "", flag_elimina_2: "")

    get classifica_path
    assert_response :success
    assert_select "h2", /Classe 4/
    assert_select "td", /FOO/
  end
end

require "test_helper"

class CaricamentiControllerTest < ActionDispatch::IntegrationTest
  setup do
    Materia.find_or_create_by!(codice: 200)  { |m| m.nome = "L"; m.ordine = 10 }
    Materia.find_or_create_by!(codice: 300)  { |m| m.nome = "D"; m.ordine = 20 }
    Materia.find_or_create_by!(codice: 1500) { |m| m.nome = "A"; m.ordine = 32 }
  end

  test "GET new renders upload form" do
    get new_caricamento_path
    assert_response :success
    assert_select "form input[type=file][name='file']"
  end

  test "POST create imports file and redirects to classifica" do
    file = fixture_file_upload("sample_capo.txt", "text/plain")
    assert_difference -> { RigaCapo.count }, 3 do
      post caricamenti_path, params: { file: file }
    end
    assert_redirected_to classifica_path
  end

  test "POST create with no file shows error" do
    post caricamenti_path
    assert_response :unprocessable_content
    assert_select ".error", /file/i
  end
end

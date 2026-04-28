# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.2].define(version: 2026_04_28_143356) do
  create_table "caricamenti", force: :cascade do |t|
    t.datetime "caricato_il"
    t.datetime "created_at", null: false
    t.string "filename"
    t.integer "righe_count"
    t.datetime "updated_at", null: false
  end

  create_table "materie", force: :cascade do |t|
    t.integer "codice"
    t.datetime "created_at", null: false
    t.string "nome"
    t.integer "ordine"
    t.datetime "updated_at", null: false
    t.index ["codice"], name: "index_materie_on_codice", unique: true
  end

  create_table "righe_capo", force: :cascade do |t|
    t.integer "alunni"
    t.string "anno"
    t.string "autore"
    t.integer "caricamento_id", null: false
    t.integer "classe"
    t.datetime "created_at", null: false
    t.string "editore"
    t.string "editore_codice"
    t.string "flag_a"
    t.string "flag_b"
    t.string "flag_d"
    t.string "isbn"
    t.integer "materia_id", null: false
    t.boolean "scorrimento"
    t.integer "sezioni"
    t.string "tipo_libro"
    t.string "titolo"
    t.datetime "updated_at", null: false
    t.index ["caricamento_id"], name: "index_righe_capo_on_caricamento_id"
    t.index ["classe", "materia_id"], name: "index_righe_capo_on_classe_and_materia_id"
    t.index ["materia_id"], name: "index_righe_capo_on_materia_id"
  end

  add_foreign_key "righe_capo", "caricamenti"
  add_foreign_key "righe_capo", "materie"
end

class CreateRigheCapo < ActiveRecord::Migration[8.2]
  def change
    create_table :righe_capo do |t|
      t.references :caricamento, null: false, foreign_key: true
      t.references :materia, null: false, foreign_key: true
      t.integer :classe
      t.string :isbn
      t.string :titolo
      t.string :autore
      t.string :editore_codice
      t.string :editore
      t.integer :sezioni
      t.integer :alunni
      t.string :anno
      t.boolean :scorrimento
      t.string :flag_elimina_1
      t.string :flag_elimina_2

      t.timestamps
    end

    add_index :righe_capo, [:classe, :materia_id]
  end
end

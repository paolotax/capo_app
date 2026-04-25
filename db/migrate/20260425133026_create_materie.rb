class CreateMaterie < ActiveRecord::Migration[8.2]
  def change
    create_table :materie do |t|
      t.integer :codice
      t.string :nome
      t.integer :ordine

      t.timestamps
    end
    add_index :materie, :codice, unique: true
  end
end

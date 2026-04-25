class CreateCaricamenti < ActiveRecord::Migration[8.2]
  def change
    create_table :caricamenti do |t|
      t.string :filename
      t.datetime :caricato_il
      t.integer :righe_count

      t.timestamps
    end
  end
end

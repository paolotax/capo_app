class ReplaceFlagsOnRigheCapo < ActiveRecord::Migration[8.2]
  def change
    remove_column :righe_capo, :flag_elimina_1, :string
    remove_column :righe_capo, :flag_elimina_2, :string

    add_column :righe_capo, :flag_a,     :string
    add_column :righe_capo, :flag_b,     :string
    add_column :righe_capo, :flag_d,     :string
    add_column :righe_capo, :tipo_libro, :string
  end
end

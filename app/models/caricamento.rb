class Caricamento < ApplicationRecord
  has_many :righe_capo, class_name: "RigaCapo", dependent: :delete_all

  validates :filename,    presence: true
  validates :caricato_il, presence: true
end

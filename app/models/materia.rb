class Materia < ApplicationRecord
  has_many :righe_capo, class_name: "RigaCapo", dependent: :restrict_with_error

  validates :codice, presence: true, uniqueness: true
  validates :nome,   presence: true
  validates :ordine, presence: true

  scope :ordinate, -> { order(:ordine, :codice) }
end

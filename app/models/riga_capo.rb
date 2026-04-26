class RigaCapo < ApplicationRecord
  self.table_name = "righe_capo"

  belongs_to :caricamento
  belongs_to :materia

  validates :classe,  presence: true, inclusion: { in: 1..5 }
  validates :sezioni, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :alunni,  presence: true, numericality: { greater_than_or_equal_to: 0 }
end

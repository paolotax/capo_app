class ClassificaQuery
  def initialize(classe:, materia:)
    @classe  = classe
    @materia = materia
  end

  def righe
    rows = base.to_a
    tot  = rows.sum { |r| r.sezioni.to_i }.to_f
    return [] if tot.zero?

    rows.map do |r|
      r.attributes.merge("quota" => (r.sezioni.to_f / tot * 100).round(1))
    end
  end

  private

  def base
    RigaCapo
      .where(classe: @classe, materia: @materia)
      .where("sezioni > 0")
      .group(:isbn, :titolo, :autore, :editore)
      .select("isbn, titolo, autore, editore,
               SUM(sezioni) AS sezioni,
               SUM(alunni)  AS alunni")
      .order(Arel.sql("SUM(sezioni) DESC"))
  end
end

module CaricamentoCapo
  class Parser
    def initialize(path)
      @path = path
    end

    def call
      File.foreach(@path, chomp: true).filter_map { |line| parse_row(line) }
    end

    private

    def parse_row(line)
      cols = line.split("\t")
      return nil if cols.size < 23

      alunni  = cols[4..8].map(&:to_i)
      sezioni = cols[15..19].map(&:to_i)
      return nil if (alunni + sezioni).all?(&:zero?)

      righe = (1..5).filter_map do |classe|
        idx = classe - 1
        next if alunni[idx].zero? && sezioni[idx].zero?
        { classe: classe, sezioni: sezioni[idx], alunni: alunni[idx] }
      end

      {
        materia_codice:  cols[0].to_i,
        editore_codice:  cols[1],
        anno:            cols[2],
        flag_elimina_1:  cols[3],
        flag_elimina_2:  cols[9],
        titolo:          cols[11],
        autore:          cols[12],
        editore:         cols[13],
        isbn:            cols[21],
        righe:           righe
      }
    end
  end
end

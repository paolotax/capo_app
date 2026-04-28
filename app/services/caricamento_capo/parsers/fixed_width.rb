module CaricamentoCapo
  module Parsers
    class FixedWidth
      LINE_LENGTH    = 264
      ALUNNI_RANGES  = [20..27, 28..35, 36..43, 44..51, 52..59].freeze
      SEZIONI_RANGES = [209..216, 217..224, 225..232, 233..240, 241..248].freeze

      def initialize(path)
        @path = path
      end

      def call
        text = File.binread(@path).force_encoding("Windows-1252").encode("UTF-8")
        text.each_line.filter_map { |raw| parse_row(raw.chomp) }
      end

      private

      def parse_row(line)
        return nil if line.length != LINE_LENGTH

        alunni  = ALUNNI_RANGES.map  { |r| line[r].to_i }
        sezioni = SEZIONI_RANGES.map { |r| line[r].to_i }
        return nil if (alunni + sezioni).all?(&:zero?)

        righe = (1..5).filter_map do |classe|
          idx = classe - 1
          next if alunni[idx].zero? && sezioni[idx].zero?
          { classe: classe, sezioni: sezioni[idx], alunni: alunni[idx] }
        end

        {
          materia_codice: line[0..5].strip.to_i,
          editore_codice: line[6..12].strip,
          anno:           line[14..17],
          flag_a:         line[18].to_s.strip,
          flag_b:         line[19].to_s.strip,
          flag_d:         line[208].to_s.strip,
          tipo_libro:     line[71],
          titolo:         line[72..147].rstrip,
          autore:         line[148..177].rstrip,
          editore:        line[178..207].rstrip,
          isbn:           line[250..262],
          righe:          righe
        }
      end
    end
  end
end

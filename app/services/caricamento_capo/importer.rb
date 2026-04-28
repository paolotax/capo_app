module CaricamentoCapo
  class Importer
    class EmptyImportError < StandardError; end

    def initialize(uploaded_file)
      @uploaded = uploaded_file
    end

    def call
      stored_path = persist_to_tmp(@uploaded)
      ActiveRecord::Base.transaction do
        caricamento = Caricamento.create!(
          filename:    @uploaded.original_filename,
          caricato_il: Time.current
        )

        rows  = Parser.new(stored_path).call
        raise EmptyImportError, "nessuna riga valida nel file" if rows.empty?

        cache = materia_cache_for(rows)
        attrs = build_riga_attrs(rows, caricamento, cache)

        RigaCapo.insert_all!(attrs) if attrs.any?

        Caricamento.where.not(id: caricamento.id).destroy_all
        caricamento.update!(righe_count: attrs.size)
        caricamento
      end
    end

    private

    def persist_to_tmp(uploaded)
      dir = Rails.root.join("tmp/uploads")
      FileUtils.mkdir_p(dir)
      path = dir.join("#{Time.current.to_i}_#{uploaded.original_filename}")
      File.binwrite(path, uploaded.read)
      path
    end

    def materia_cache_for(rows)
      codici = rows.map { |r| r[:materia_codice] }.uniq
      cache  = Materia.where(codice: codici).index_by(&:codice)
      codici.each do |codice|
        next if cache[codice]
        cache[codice] = Materia.create!(
          codice: codice,
          nome:   "Materia #{codice}",
          ordine: 999
        )
        Rails.logger.warn("[CaricamentoCapo] codice materia sconosciuto: #{codice} (creato placeholder)")
      end
      cache
    end

    def build_riga_attrs(rows, caricamento, cache)
      now = Time.current
      rows.flat_map do |row|
        materia_id = cache.fetch(row[:materia_codice]).id
        row[:righe].map do |sub|
          {
            caricamento_id:   caricamento.id,
            materia_id:       materia_id,
            classe:           sub[:classe],
            isbn:             row[:isbn],
            titolo:           row[:titolo],
            autore:           row[:autore],
            editore_codice:   row[:editore_codice],
            editore:          row[:editore],
            sezioni:          sub[:sezioni],
            alunni:           sub[:alunni],
            anno:             row[:anno],
            scorrimento:      sub[:classe] == 5,
            flag_a:           row[:flag_a],
            flag_b:           row[:flag_b],
            flag_d:           row[:flag_d],
            tipo_libro:       row[:tipo_libro],
            created_at:       now,
            updated_at:       now
          }
        end
      end
    end
  end
end

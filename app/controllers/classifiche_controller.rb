class ClassificheController < ApplicationController
  CLASSI = [1, 4].freeze

  def show
    return redirect_to(new_caricamento_path) if RigaCapo.none?

    @ultimo_caricamento = Caricamento.order(:caricato_il).last
    @classifiche = CLASSI.index_with do |classe|
      Materia.ordinate
             .joins(:righe_capo)
             .where(righe_capo: { classe: classe })
             .where("righe_capo.sezioni > 0")
             .distinct
    end
  end
end

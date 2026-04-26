class CaricamentiController < ApplicationController
  def new
  end

  def create
    if params[:file].blank?
      @error = "Seleziona un file."
      return render :new, status: :unprocessable_content
    end

    CaricamentoCapo::Importer.new(params[:file]).call
    redirect_to classifica_path, notice: "File caricato. Classifiche aggiornate."
  rescue StandardError => e
    Rails.logger.error("[Caricamento] #{e.class}: #{e.message}")
    @error = "Errore nell'import: #{e.message}"
    render :new, status: :unprocessable_content
  end

  def destroy
    Caricamento.find(params[:id]).destroy
    redirect_to new_caricamento_path, notice: "Snapshot rimossa."
  end
end

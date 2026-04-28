module CaricamentoCapo
  class Parser
    def initialize(path)
      @path = path
    end

    def call
      strategy_for(Detector.call(@path)).new(@path).call
    end

    private

    def strategy_for(format)
      case format
      when :tab         then Parsers::Tab
      when :fixed_width then Parsers::FixedWidth
      end
    end
  end
end

module CaricamentoCapo
  class Detector
    class UnknownFormatError < StandardError; end

    FIXED_WIDTH_LINE_LENGTH = 264

    def self.call(path)
      sample = first_non_empty_line(path)
      raise UnknownFormatError, "file empty or unreadable" if sample.nil?

      return :fixed_width if fixed_width?(sample)
      return :tab         if sample.include?("\t")

      raise UnknownFormatError, "no tabs and not a #{FIXED_WIDTH_LINE_LENGTH}-char fixed-width line"
    end

    def self.first_non_empty_line(path)
      File.open(path, "rb") do |f|
        f.each_line do |line|
          stripped = line.chomp
          return stripped unless stripped.empty?
        end
      end
      nil
    end
    private_class_method :first_non_empty_line

    def self.fixed_width?(line)
      line.bytesize == FIXED_WIDTH_LINE_LENGTH &&
        line.byteslice(249) == "*" &&
        line.byteslice(263) == "*"
    end
    private_class_method :fixed_width?
  end
end

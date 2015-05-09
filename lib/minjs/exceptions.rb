module Minjs
  class ParseError < StandardError
    def initialize(error_message = nil, lex = nil)
      super(error_message)
      @lex = lex
    end

    def to_s
      t = ''
      t << super
      t << "\n"
      t << @lex.debug_str if @lex
    end
  end
end

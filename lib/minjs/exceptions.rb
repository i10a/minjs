module Minjs
  class ParseError < StandardError
    def initialize(error_message = nil, lex = nil)
      super(error_message)
      if lex
        @lex = lex
        @lex_pos = lex.pos
      end
    end

    def to_s
      t = ''
      t << super
      t << "\n"
      if @lex
        line, col = @lex.line_col(@lex_pos)
        t << "line: #{line}, col: #{col}\n"
        t << @lex.debug_str(@lex_pos, line, col)
      end
      t
    end
  end
end

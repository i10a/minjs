module Minjs::Lex
  # ParseError
  class ParseError < StandardError
    def initialize(error_message = nil, lex = nil)
      super(error_message)
      if lex
        @lex = lex
        @lex_pos = lex.pos
      end
    end

    # to string
    def to_s
      t = ''
      t << super
      t << "\n"
      if @lex
        row, col = @lex.row_col(@lex_pos)
        t << "row: #{row}, col: #{col}\n"
        t << @lex.debug_str(@lex_pos, row, col)
      end
      t
    end
  end
end

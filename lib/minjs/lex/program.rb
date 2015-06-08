module Minjs::Lex
  #
  # 14 Program
  #
  module Program
    include Minjs
    def program(context)
      prog = source_elements(context)
      if lex.eof?
        return prog
      else
        raise ParseError.new("unexpceted token", lex)
      end
    end

    def source_elements(context)
      prog = []
      while t = source_element(context)
        prog.push(t)
      end
      ECMA262::Prog.new(context, ECMA262::SourceElements.new(prog))
    end

    def source_element(context)
      #lex.eval_lit{
      statement(context)
      #} or lex.eval_lit{ => statement
      #  func_declaration(context)
      #}
    end
  end
end


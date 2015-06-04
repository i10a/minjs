module Minjs
  #
  # 14 Program
  #
  module Program
    def program(lex, context)
      prog = source_elements(@lex, @global_context)
      if lex.eof?
        return prog
      else
        raise ParseError.new("unexpceted token", lex)
      end
    end

    def source_elements(lex, context, options = {})
      prog = []
      while t = source_element(lex, context)
        prog.push(t)
      end
      ECMA262::Prog.new(context, ECMA262::SourceElements.new(prog))
    end

    def source_element(lex, context)
      #lex.eval_lit{
      statement(lex, context)
      #} or lex.eval_lit{ => statement
      #  func_declaration(lex, context)
      #}
    end
  end
end


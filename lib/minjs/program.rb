module Minjs
  #
  # 14 Program
  #
  module Program
    def source_elements(lex, context, options = {})
      prog = []
      while t = source_element(lex, context)
        prog.push(t)
      end
      ECMA262::Prog.new(context, ECMA262::SourceElements.new(prog))
    end

    def source_element(lex, context)
      lex.eval_lit{
        statement(lex, context)
      } or lex.eval_lit{
        func_declaration(lex, context)
      }
    end
  end
end


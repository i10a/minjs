module Minjs
  #
  # 14 Program
  #
  module Program
    def source_elements(lex, context, options = {})
      prog = []
      while !lex.eof?
        t = source_element(lex, context)
        if t
          prog.push(t)
        else
          break
        end
      end
      ECMA262::Prog.new(context, prog)
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


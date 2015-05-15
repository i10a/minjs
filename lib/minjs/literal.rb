module Minjs
  module Literal
    #
    # 7.8
    #
    def literal(lex, context)
      lex.eval_lit{
        a = lex.fwd_lit(:hint => :regexp)
        if a.kind_of?(ECMA262::ECMA262Numeric) || a.kind_of?(ECMA262::ECMA262String) || a.kind_of?(ECMA262::ECMA262RegExp)
          a
        else
          nil
        end
      } or lex.eval_lit{
        null_literal(lex, context)
      } or lex.eval_lit{
        boolean_literal(lex, context)
      }
    end

    #
    # 7.8.1
    #
    def null_literal(lex, context)
      if lex.match_lit(ECMA262::ID_NULL)
        ECMA262::Null.get
      else
        nil
      end
    end

    #
    # 7.8.2
    #
    def boolean_literal(lex, context)
      if lex.match_lit(ECMA262::ID_TRUE)
        ECMA262::Boolean.get(:true)
      elsif lex.match_lit(ECMA262::ID_FALSE)
        ECMA262::Boolean.get(:false)
      else
        nil
      end
    end
  end
end

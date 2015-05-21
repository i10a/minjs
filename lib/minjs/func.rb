module Minjs
  module Func
    #
    #13
    #
    def func_declaration(lex, context)
      return nil if lex.match_lit(ECMA262::ID_FUNCTION).nil?
      lex.eval_lit {
        new_context = ECMA262::Context.new
        new_context.lex_env = context.lex_env.new_declarative_env()
        new_context.var_env = context.var_env.new_declarative_env()

        if id=identifier(lex, context) and
          lex.match_lit(ECMA262::PUNC_LPARENTHESIS) and
          args = formal_parameter_list(lex, new_context) and
          lex.match_lit(ECMA262::PUNC_RPARENTHESIS) and
          lex.match_lit(ECMA262::PUNC_LCURLYBRAC) and
          b=func_body(lex, new_context) and lex.match_lit(ECMA262::PUNC_RCURLYBRAC)
          f = ECMA262::StFunc.new(new_context, id, args, b, {:decl => true})

          context.var_env.record.create_mutable_binding(id, nil)
          context.var_env.record.set_mutable_binding(id, f, nil)
          context.lex_env.record.create_mutable_binding(id, nil)
          context.lex_env.record.set_mutable_binding(id, f, nil)
          f
        else
          if b
            raise ParseError.new("No `}' at end of function", lex)
          else
            raise ParseError.new("Bad function declaration", lex)
          end
        end
      }
    end

    def func_exp(lex, context)
      return nil if lex.match_lit(ECMA262::ID_FUNCTION).nil?
      @logger.debug "*** func_exp"

      lex.eval_lit {
        id_opt = identifier(lex, context)
        new_context = ECMA262::Context.new
        new_context.lex_env = context.lex_env.new_declarative_env()
        new_context.var_env = context.var_env.new_declarative_env()

         if lex.match_lit(ECMA262::PUNC_LPARENTHESIS) and
           args = formal_parameter_list(lex, new_context) and
           lex.match_lit(ECMA262::PUNC_RPARENTHESIS) and
           lex.match_lit(ECMA262::PUNC_LCURLYBRAC) and
           b = func_body(lex, new_context) and lex.match_lit(ECMA262::PUNC_RCURLYBRAC)
           f = ECMA262::StFunc.new(new_context, id_opt, args, b)
           if id_opt
             new_context.var_env.record.create_mutable_binding(id_opt, nil)
             new_context.var_env.record.set_mutable_binding(id_opt, f, nil)
             new_context.lex_env.record.create_mutable_binding(id_opt, nil)
             new_context.lex_env.record.set_mutable_binding(id_opt, f, nil)
             id_opt.context = new_context
           end
           f
         else
          if b
            raise ParseError.new("No `}' at end of function", lex)
          else
            raise ParseError.new("Bad function declaration", lex)
          end
         end
       }
    end

    def formal_parameter_list(lex, context)
      lex.eval_lit{
        ret = []
        while true
          a = identifier(lex, context)
          if a
            ret.push(a)
            break if lex.match_lit(ECMA262::PUNC_COMMA).nil?
          else
            break
          end
        end
        ret.each do |argName|
          context.var_env.record.create_mutable_binding(argName, nil)
          context.var_env.record.set_mutable_binding(argName, :undefined, nil, {:_parameter_list => true})
          context.lex_env.record.create_mutable_binding(argName, nil)
          context.lex_env.record.set_mutable_binding(argName, :undefined, nil, {:_parameter_list => true})
        end
        ret
      }
    end

    def func_body(lex, context)
      source_elements(lex, context)
    end
  end
end

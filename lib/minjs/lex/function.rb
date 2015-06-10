module Minjs::Lex
  module Function
    include Minjs
    # Tests next literal is FunctionDeclaration or not.
    #
    # If literal is FunctionDeclaration
    # return ECMA262::StFunc object and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 13
    #
    # @note
    #   The function declaration in statement(block) is not permitted by ECMA262.
    #   However, almost all implementation permit it, so minjs cannot raise
    #   exception even if function declarataion in block.
    #
    def func_declaration(context)
      # FunctionDeclaration :
      # function Identifier ( FormalParameterListopt ) { FunctionBody }
      return nil if lex.eql_lit?(ECMA262::ID_FUNCTION).nil?

      new_context = ECMA262::Context.new
      new_context.lex_env = context.lex_env.new_declarative_env()
      new_context.var_env = context.var_env.new_declarative_env()

      if id=identifier(context) and
        lex.eql_lit?(ECMA262::PUNC_LPARENTHESIS) and
        args = formal_parameter_list(new_context) and
        lex.eql_lit?(ECMA262::PUNC_RPARENTHESIS) and
        lex.eql_lit?(ECMA262::PUNC_LCURLYBRAC) and
        b=func_body(new_context) and lex.eql_lit?(ECMA262::PUNC_RCURLYBRAC)
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
    end

    # Tests next literal is FunctionExpression or not.
    #
    # If literal is FunctionExpression
    # return ECMA262::StFunc object and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 13
    #
    # @note
    #   The function expression and declaration uses same class
    #   for convenience.
    #
    def func_exp(context)
      # FunctionExpression :
      # function Identifieropt ( FormalParameterListopt ) { FunctionBody }
      return nil if lex.eql_lit?(ECMA262::ID_FUNCTION).nil?
      @logger.debug "*** func_exp"

      id_opt = identifier(context)
      new_context = ECMA262::Context.new
      new_context.lex_env = context.lex_env.new_declarative_env()
      new_context.var_env = context.var_env.new_declarative_env()

      if lex.eql_lit?(ECMA262::PUNC_LPARENTHESIS) and
        args = formal_parameter_list(new_context) and
        lex.eql_lit?(ECMA262::PUNC_RPARENTHESIS) and
        lex.eql_lit?(ECMA262::PUNC_LCURLYBRAC) and
        b = func_body(new_context) and lex.eql_lit?(ECMA262::PUNC_RCURLYBRAC)
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
          raise ParseError.new("Bad function expression", lex)
        end
      end
    end

    def formal_parameter_list(context)
      ret = []
      unless lex.peek_lit(nil).eql? ECMA262::PUNC_RPARENTHESIS
        while true
          if arg = identifier(context)
            ret.push(arg)
          else
            raise ParseError.new("unexpceted token", lex)
          end
          if lex.peek_lit(nil).eql? ECMA262::PUNC_RPARENTHESIS
            break
          elsif lex.eql_lit? ECMA262::PUNC_COMMA
            ;
          else
            raise ParseError.new("unexpceted token", lex)
          end
        end
      end
      ret.each do |argName|
        context.var_env.record.create_mutable_binding(argName, nil)
        context.var_env.record.set_mutable_binding(argName, :undefined, nil, {:_parameter_list => true})
        context.lex_env.record.create_mutable_binding(argName, nil)
        context.lex_env.record.set_mutable_binding(argName, :undefined, nil, {:_parameter_list => true})
      end
      ret
    end

    def func_body(context)
      source_elements(context)
    end

    private :func_body, :formal_parameter_list
  end
end

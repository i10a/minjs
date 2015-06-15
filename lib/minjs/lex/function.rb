module Minjs::Lex
  # Function
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
    def func_declaration(var_env)
      # FunctionDeclaration :
      # function Identifier ( FormalParameterListopt ) { FunctionBody }
      return nil if eql_lit?(ECMA262::ID_FUNCTION).nil?

      new_var_env = ECMA262::LexEnv.new(outer: var_env)

      if id=identifier(var_env) and
        eql_lit?(ECMA262::PUNC_LPARENTHESIS) and
        args = formal_parameter_list(new_var_env) and
        eql_lit?(ECMA262::PUNC_RPARENTHESIS) and
        eql_lit?(ECMA262::PUNC_LCURLYBRAC) and
        b=func_body(new_var_env) and eql_lit?(ECMA262::PUNC_RCURLYBRAC)
        f = ECMA262::StFunc.new(new_var_env, id, args, b, {:decl => true})

        var_env.record.create_mutable_binding(id, nil)
        var_env.record.set_mutable_binding(id, f, nil)
        f
      else
        if b
          raise ParseError.new("No `}' at end of function", self)
        else
          raise ParseError.new("Bad function declaration", self)
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
    def func_exp(var_env)
      # FunctionExpression :
      # function Identifieropt ( FormalParameterListopt ) { FunctionBody }
      return nil if eql_lit?(ECMA262::ID_FUNCTION).nil?
      @logger.debug "*** func_exp"

      id_opt = identifier(var_env)
      new_var_env = ECMA262::LexEnv.new(outer: var_env)

      if eql_lit?(ECMA262::PUNC_LPARENTHESIS) and
        args = formal_parameter_list(new_var_env) and
        eql_lit?(ECMA262::PUNC_RPARENTHESIS) and
        eql_lit?(ECMA262::PUNC_LCURLYBRAC) and
        b = func_body(new_var_env) and eql_lit?(ECMA262::PUNC_RCURLYBRAC)
        f = ECMA262::StFunc.new(new_var_env, id_opt, args, b)
        #new_var_env.func = f
        if id_opt
          var_env.record.create_mutable_binding(id_opt, nil)
          var_env.record.set_mutable_binding(id_opt, f, nil)
        end
        f
      else
        if b
          raise ParseError.new("No `}' at end of function", self)
        else
          raise ParseError.new("Bad function expression", self)
        end
      end
    end

    def formal_parameter_list(var_env)
      ret = []
      unless peek_lit(nil).eql? ECMA262::PUNC_RPARENTHESIS
        while true
          if arg = identifier(var_env)
            ret.push(arg)
          else
            raise ParseError.new("unexpceted token", self)
          end
          if peek_lit(nil).eql? ECMA262::PUNC_RPARENTHESIS
            break
          elsif eql_lit? ECMA262::PUNC_COMMA
            ;
          else
            raise ParseError.new("unexpceted token", self)
          end
        end
      end
      ret.each do |argName|
        var_env.record.create_mutable_binding(argName, nil)
        var_env.record.set_mutable_binding(argName, :undefined, nil, _parameter_list: true)
      end
      ret
    end

    def func_body(var_env)
      source_elements(var_env)
    end

    private :func_body, :formal_parameter_list
  end
end

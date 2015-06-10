module Minjs::Lex
  #
  # 12
  #
  module Statement
    include Minjs
    #
    # check next literal is ';' or '}' or LT
    #
    def semicolon(context)
      a = lex.peek_lit_nolt(nil)
      # ; ?
      if a == ECMA262::PUNC_SEMICOLON
        lex.fwd_after_peek
        a
      # } ?
      elsif a == ECMA262::PUNC_RCURLYBRAC
        a
      # line feed?
      elsif a == ECMA262::LIT_LINE_TERMINATOR
        lex.fwd_after_peek
        a
      # end of program
      elsif a.nil?
        lex.fwd_after_peek
        ECMA262::LIT_LINE_TERMINATOR
      # line terminator?
      elsif a.lt?
        lex.fwd_after_peek
        a
      else
        nil
      end
    end

    #12
    def statement(context)
      (
        block(context) or		#12.1
        var_statement(context) or	#12.2
        if_statement(context) or	#12.5
        iteration_statement(context) or	#12.6
        continue_statement(context) or	#12.7
        break_statement(context) or	#12.8
        return_statement(context) or	#12.9
        with_statement(context) or	#12.10
        switch_statement(context) or	#12.11
        labelled_statement(context) or	#12.12
        throw_statement(context) or	#12.13
        try_statement(context) or	#12.14
        debugger_statement(context) or	#12.15
        func_declaration(context) or	#13 => func.rb
        exp_statement(context) or	#12.4
        empty_statement(context) 	#12.3
      )
    end
    #
    #12.1
    # block
    def block(context)
      pos0 = lex.pos
      return nil unless lex.eql_lit?(ECMA262::PUNC_LCURLYBRAC)
      if lex.eql_lit?(ECMA262::PUNC_RCURLYBRAC)
        return ECMA262::StBlock.new(ECMA262::StatementList.new([]))
      end

      if s = statement_list(context) and lex.eql_lit?(ECMA262::PUNC_RCURLYBRAC)
        ECMA262::StBlock.new(s)
      else
        raise ParseError.new('no "}" end of block', lex)
      end
    end

    def statement_list(context)
      t = []
      while !lex.eof? and s = statement(context)
        t.push(s)
      end
      ECMA262::StatementList.new(t)
    end
    #
    #12.2
    # variable_statement
    #
    def var_statement(context)
      raise 'internal error' if context.nil?
      return nil unless lex.eql_lit?(ECMA262::ID_VAR)

      if vl = var_decl_list(context, {}) and semicolon(context)
        #10.5
        vl.each do |v|
          dn = v[0]
          context.var_env.record.create_mutable_binding(dn, nil)
          context.var_env.record.set_mutable_binding(dn, :undefined, nil)
          context.lex_env.record.create_mutable_binding(dn, nil)
          context.lex_env.record.set_mutable_binding(dn, :undefined, nil)
        end
        ECMA262::StVar.new(context, vl)
      else
        raise Minjs::ParseError.new("unexpected token", lex)
      end
    end
    # 12.2
    #
    # VariableDeclarationList :
    # VariableDeclaration
    # VariableDeclarationList , VariableDeclaration
    #
    def var_decl_list(context, options)
      list = []
      list.push(var_decl(context, options))

      while lex.eql_lit?(ECMA262::PUNC_COMMA) and b = var_decl(context, options)
        list.push(b)
      end
      list
    end

    # 12.2
    #
    # VariableDeclaration :
    # Identifier Initialiser[opt]
    #
    # return tuple of [name, initialiser]
    #
    def var_decl(context, options)
      a = identifier(context)
      if !a
        raise ParseError.new("bad identifier", lex);
      else
        b = initialiser(context, options)
        [a, b]
      end
    end

    # 12.2
    #
    # Initialiser :
    # = AssignmentExpression
    #
    def initialiser(context, options)
      if lex.eql_lit?(ECMA262::PUNC_LET)
        if a = assignment_exp(context, options)
          return a
        else
          raise ParseError.new("unexpceted token", lex);
        end
      end
      nil
    end
    #
    #12.3
    #
    def empty_statement(context)
      a = lex.peek_lit(nil)
      if a == ECMA262::PUNC_SEMICOLON
        lex.fwd_after_peek
        ECMA262::StEmpty.new
      else
        nil
      end
    end
    #
    #12.4
    #
    def exp_statement(context)
      if (a = lex.peek_lit(nil)).eql? ECMA262::PUNC_LCURLYBRAC
        return block(context)
      end
      if a.eql? ECMA262::ID_FUNCTION
        return func_declaration(context)
      end


      if a = exp(context, {})
        if semicolon(context)
          ECMA262::StExp.new(a)
        # There is a possibility of labelled statemet if
        # exp_statement call before labelled_statement
        else
          raise ParseError.new("no semicolon at end of expression statement", lex)
        end
      else
        nil
      end
    end
    #
    #12.5
    #
    def if_statement(context)
      return nil unless lex.eql_lit?(ECMA262::ID_IF)
      unless(lex.eql_lit?(ECMA262::PUNC_LPARENTHESIS) and cond=exp(context, {}) and
             lex.eql_lit?(ECMA262::PUNC_RPARENTHESIS) and s = statement(context))
        raise ParseError.new("unexpected token", lex)
      end
      if(lex.eql_lit?(ECMA262::ID_ELSE) and e = statement(context))
        ECMA262::StIf.new(cond, s, e)
      else
        ECMA262::StIf.new(cond, s, nil)
      end
    end
    #
    # 12.6
    #
    def iteration_statement(context)
      for_statement(context) or while_statement(context) or do_while_statement(context)
    end

    def while_statement(context)
      return nil unless lex.eql_lit?(ECMA262::ID_WHILE)
      if lex.eql_lit?(ECMA262::PUNC_LPARENTHESIS) and e=exp(context, {}) and lex.eql_lit?(ECMA262::PUNC_RPARENTHESIS) and s=statement(context)
        ECMA262::StWhile.new(e, s)
      else
        raise ParseError.new("unexpected token", lex)
      end
    end

    def do_while_statement(context)
      return nil unless lex.eql_lit?(ECMA262::ID_DO)
      if s=statement(context) and lex.eql_lit?(ECMA262::ID_WHILE) and lex.eql_lit?(ECMA262::PUNC_LPARENTHESIS) and e=exp(context, {}) and lex.eql_lit?(ECMA262::PUNC_RPARENTHESIS) and semicolon(context)
        ECMA262::StDoWhile.new(e, s)
      else
        raise ParseError.new("unexpected token", lex)
      end
    end

    #12.6
    #
    # for ( ExpressionNoInopt ; Expressionopt ; Expressionopt ) Statement
    # for ( var VariableDeclarationListNoIn ; Expressionopt ; Expressionopt ) Statement
    # for ( LeftHandSideExpression in Expression ) Statement
    # for ( var VariableDeclarationNoIn in Expression ) Statement
    #
    def for_statement(context)
      return nil unless lex.eql_lit?(ECMA262::ID_FOR)
      raise ParseError('unexpected token', lex) unless lex.eql_lit?(ECMA262::PUNC_LPARENTHESIS)
      lex.eval_lit{
        # for(var i in a)
        if lex.eql_lit?(ECMA262::ID_VAR)
          lex.eval_lit{
            if v=var_decl(context, :no_in => true) and lex.eql_lit?(ECMA262::ID_IN)
              if e=exp(context, {}) and lex.eql_lit?(ECMA262::PUNC_RPARENTHESIS) and s = statement(context)
                #10.5
                context.var_env.record.create_mutable_binding(v[0], nil)
                context.var_env.record.set_mutable_binding(v[0], :undefined, nil)
                context.lex_env.record.create_mutable_binding(v[0], nil)
                context.lex_env.record.set_mutable_binding(v[0], :undefined, nil)
                ECMA262::StForInVar.new(context, v, e, s)
              else
                raise ParseError.new("unexpected token", lex)
              end
            end
          } or lex.eval_lit {
            # for(var i ; cond ; exp)
            if vl=var_decl_list(context, :no_in =>true) and s1=lex.eql_lit?(ECMA262::PUNC_SEMICOLON) and (e=exp(context, {})||true) and s2=lex.eql_lit?(ECMA262::PUNC_SEMICOLON) and (e2=exp(context, {})||true) and lex.eql_lit?(ECMA262::PUNC_RPARENTHESIS) and s=statement(context)
              e = nil if e == true
              e2 = nil if e2 == true
              #10.5
              vl.each do |v|
                dn = v[0]
                context.var_env.record.create_mutable_binding(dn, nil)
                context.var_env.record.set_mutable_binding(dn, :undefined, nil)
                context.lex_env.record.create_mutable_binding(dn, nil)
                context.lex_env.record.set_mutable_binding(dn, :undefined, nil)
              end
              ECMA262::StForVar.new(context, vl, e, e2, s)
            else
              if !s1
                raise ParseError.new("no semicolon", lex)
              elsif !s2
                raise ParseError.new("no semicolon", lex)
              else
                raise ParseError.new("unexpected token", lex)
              end
            end
          }
        else # => for(i in exp) / for(i ; cond; exp)
          lex.eval_lit{
            # for(i in exp)
            if v=left_hand_side_exp(context) and lex.eql_lit?(ECMA262::ID_IN)
              if e=exp(context, {}) and lex.eql_lit?(ECMA262::PUNC_RPARENTHESIS) and s=statement(context)
                ECMA262::StForIn.new(v, e, s)
              else
                raise ParseError.new("unexpected token", lex)
              end
            end
          } or lex.eval_lit{
            # for(i ; cond; exp)
            if (v=exp(context, :no_in => true) || true) and s1=lex.eql_lit?(ECMA262::PUNC_SEMICOLON) and (e=exp(context, {}) || true) and s2=lex.eql_lit?(ECMA262::PUNC_SEMICOLON) and (e2=exp(context, {})||true) and lex.eql_lit?(ECMA262::PUNC_RPARENTHESIS) and s=statement(context)
              v = nil if v == true
              e = nil if e == true
              e2 = nil if e2 == true
              ECMA262::StFor.new(v, e, e2, s)
            else
              raise ParseError.new("unexpected token", lex)
            end
          }
        end
      }
    end
    #
    # 12.7
    #
    def continue_statement(context)
      return nil unless lex.eql_lit?(ECMA262::ID_CONTINUE)

      if semicolon(context)
        ECMA262::StContinue.new
      elsif e=identifier(context) and semicolon(context)
        ECMA262::StContinue.new(e)
      else
        if e
          raise ParseError.new("no semicolon at end of continue statement", lex)
        else
          raise ParseError.new("unexpected token", lex)
        end
      end
    end
    #
    # 12.8
    #
    def break_statement(context)
      return nil unless lex.eql_lit?(ECMA262::ID_BREAK)

      if semicolon(context)
        ECMA262::StBreak.new
      elsif e=identifier(context) and semicolon(context)
        ECMA262::StBreak.new(e)
      else
        if e
          raise ParseError.new("no semicolon at end of break statement", lex)
        else
          raise ParseError.new("unexpected token", lex)
        end
      end
    end
    #
    # 12.9
    #
    def return_statement(context)
      return nil unless lex.eql_lit?(ECMA262::ID_RETURN)

      if semicolon(context)
        ECMA262::StReturn.new
      elsif e=exp(context, {}) and semicolon(context)
        ECMA262::StReturn.new(e)
      else
        raise ParseError.new("unexpected token", lex)
      end
    end
    #
    # 12.10
    #
    def with_statement(context)
      return nil unless lex.eql_lit?(ECMA262::ID_WITH)

      if lex.eql_lit?(ECMA262::PUNC_LPARENTHESIS) and e=exp(context, {}) and lex.eql_lit?(ECMA262::PUNC_RPARENTHESIS) and s=statement(context)
        ECMA262::StWith.new(context, e, s)
      else
        raise ParseError.new("unexpected token", lex)
      end
    end
    #
    # 12.11
    #
    def switch_statement(context)
      return nil unless lex.eql_lit?(ECMA262::ID_SWITCH)

      if lex.eql_lit?(ECMA262::PUNC_LPARENTHESIS) and e=exp(context, {}) and lex.eql_lit?(ECMA262::PUNC_RPARENTHESIS) and  c = case_block(context)
        ECMA262::StSwitch.new(e, c)
      else
        raise ParseError.new("unexpected token", lex)
      end
    end

    def case_block(context)
      return nil unless lex.eql_lit?(ECMA262::PUNC_LCURLYBRAC)
      _case_block = []
      while true
        if lex.eql_lit?(ECMA262::ID_CASE)
          if e = exp(context, {}) and lex.eql_lit?(ECMA262::PUNC_COLON)
            sl = statement_list(context)
            _case_block.push [e, sl]
          else
            raise ParseError.new("unexpected token", lex)
          end
        elsif lex.eql_lit?(ECMA262::ID_DEFAULT)
          if lex.eql_lit?(ECMA262::PUNC_COLON)
            sl = statement_list(context)
            _case_block.push [nil, sl]
          else
            raise ParseError.new("unexpected token", lex)
          end
        elsif lex.eql_lit?(ECMA262::PUNC_RCURLYBRAC)
          break
        end
      end
      _case_block
    end
    #
    # 12.12
    #
    def labelled_statement(context)
      lex.eval_lit {
        if i=identifier(context) and s1=lex.eql_lit?(ECMA262::PUNC_COLON)
          if s=statement(context)
            ECMA262::StLabelled.new(i, s)
          else
            raise ParseError.new("unexpected token", lex)
          end
        else
          nil
        end
      }
    end
    #
    # 12.13
    #
    def throw_statement(context)
      return nil unless lex.eql_lit?(ECMA262::ID_THROW)

      if semicolon(context)
        raise ParseError.new("no line terminator here", lex)
      elsif e=exp(context, {}) and semi = semicolon(context)
        ECMA262::StThrow.new(e)
      else
        if e
          raise ParseError.new("no semicolon at end of throw statement", lex)
        else
          raise ParseError.new("unexpected token", lex)
        end
      end
    end
    #
    # 12.14
    #
    def try_statement(context)
      return nil unless lex.eql_lit?(ECMA262::ID_TRY)
      #
      # The catch argument context must be executable lexical environment.
      # See compress_var
      #
      t = block(context)
      return nil unless t

      c = try_catch(context)
      f = try_finally(context)
      ECMA262::StTry.new(context, t, c, f)
    end
    # 12.14
    #
    # Catch :
    # catch ( Identifier ) Block
    #
    # return [identigier, block]
    #
    def try_catch(context)
      return nil unless lex.eql_lit?(ECMA262::ID_CATCH)

      if lex.eql_lit?(ECMA262::PUNC_LPARENTHESIS) and i=identifier(context) and lex.eql_lit?(ECMA262::PUNC_RPARENTHESIS) and b=block(context)
        [i, b]
      else
        raise ParseError.new("unexpected token", lex)
      end
    end

    def try_finally(context)
      return nil unless lex.eql_lit?(ECMA262::ID_FINALLY)
      b = block(context)
      raise ParseError.new("unexpected token", lex) if b.nil?
      b
    end

    #
    # 12.15
    #
    def debugger_statement(context)
      return nil unless lex.eql_lit?(ECMA262::ID_DEBUGGER)
      if semicolon(context)
        ECMA262::StDebugger.new
      else
        raise ParseError.new("no semicolon at end of debugger statement", lex)
      end
    end

  end
end


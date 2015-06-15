module Minjs::Lex
  #
  # 12
  #
  module Statement
    include Minjs
    # Tests next literal is ';' or '}' or LT
    def semicolon(var_env)
      a = peek_lit_nolt(nil)
      # ; ?
      if a == ECMA262::PUNC_SEMICOLON
        fwd_after_peek
        a
      # } ?
      elsif a == ECMA262::PUNC_RCURLYBRAC
        a
      # line feed?
      elsif a == ECMA262::LIT_LINE_TERMINATOR
        fwd_after_peek
        a
      # end of program
      elsif a.nil?
        fwd_after_peek
        ECMA262::LIT_LINE_TERMINATOR
      # line terminator?
      elsif a.lt?
        fwd_after_peek
        a
      else
        nil
      end
    end

    # Tests next literals sequence is Statement or not.
    def statement(var_env)
      (
        block(var_env) or		#12.1
        var_statement(var_env) or	#12.2
        if_statement(var_env) or	#12.5
        iteration_statement(var_env) or	#12.6
        continue_statement(var_env) or	#12.7
        break_statement(var_env) or	#12.8
        return_statement(var_env) or	#12.9
        with_statement(var_env) or	#12.10
        switch_statement(var_env) or	#12.11
        labelled_statement(var_env) or	#12.12
        throw_statement(var_env) or	#12.13
        try_statement(var_env) or	#12.14
        debugger_statement(var_env) or	#12.15
        func_declaration(var_env) or	#13 => func.rb
        exp_statement(var_env) or	#12.4
        empty_statement(var_env) 	#12.3
      )
    end
    # Tests next literals sequence is Block or not.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 12.1
    def block(var_env)
      pos0 = pos
      return nil unless eql_lit?(ECMA262::PUNC_LCURLYBRAC)
      if eql_lit?(ECMA262::PUNC_RCURLYBRAC)
        return ECMA262::StBlock.new(ECMA262::StatementList.new([]))
      end

      if s = statement_list(var_env) and eql_lit?(ECMA262::PUNC_RCURLYBRAC)
        ECMA262::StBlock.new(s)
      else
        raise ParseError.new('no "}" end of block', lex)
      end
    end

    def statement_list(var_env)
      t = []
      while !eof? and s = statement(var_env)
        t.push(s)
      end
      ECMA262::StatementList.new(t)
    end
    private :statement_list

    # Tests next literals sequence is VariableStatement or not.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 12.2
    def var_statement(var_env)
      return nil unless eql_lit?(ECMA262::ID_VAR)

      if vl = var_decl_list(var_env, {}) and semicolon(var_env)
        #10.5
        vl.each do |v|
          dn = v[0]
          var_env.record.create_mutable_binding(dn, nil)
          var_env.record.set_mutable_binding(dn, :undefined, nil)
        end
        ECMA262::StVar.new(var_env, vl)
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
    def var_decl_list(var_env, options)
      list = []
      list.push(var_decl(var_env, options))

      while eql_lit?(ECMA262::PUNC_COMMA) and b = var_decl(var_env, options)
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
    def var_decl(var_env, options)
      a = identifier(var_env)
      if !a
        raise ParseError.new("bad identifier", lex);
      else
        b = initialiser(var_env, options)
        [a, b]
      end
    end

    # 12.2
    #
    # Initialiser :
    # = AssignmentExpression
    #
    def initialiser(var_env, options)
      if eql_lit?(ECMA262::PUNC_ASSIGN)
        if a = assignment_exp(var_env, options)
          return a
        else
          raise ParseError.new("unexpceted token", self);
        end
      end
      nil
    end
    private :var_decl_list, :var_decl, :initialiser

    # Tests next literals sequence is EmptyStatement or not.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 12.3
    def empty_statement(var_env)
      a = peek_lit(nil)
      if a == ECMA262::PUNC_SEMICOLON
        fwd_after_peek
        ECMA262::StEmpty.new
      else
        nil
      end
    end
    # Tests next literals sequence is ExpressionStatement or not.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 12.4
    def exp_statement(var_env)
      if (a = peek_lit(nil)).eql? ECMA262::PUNC_LCURLYBRAC
        return block(var_env)
      end
      if a.eql? ECMA262::ID_FUNCTION
        return func_declaration(var_env)
      end


      if a = exp(var_env, {})
        if semicolon(var_env)
          ECMA262::StExp.new(a)
        # There is a possibility of labelled statemet if
        # exp_statement call before labelled_statement
        else
          raise ParseError.new("no semicolon at end of expression statement", self)
        end
      else
        nil
      end
    end
    # Tests next literals sequence is IfStatement or not.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 12.5
    def if_statement(var_env)
      return nil unless eql_lit?(ECMA262::ID_IF)
      unless(eql_lit?(ECMA262::PUNC_LPARENTHESIS) and cond=exp(var_env, {}) and
             eql_lit?(ECMA262::PUNC_RPARENTHESIS) and s = statement(var_env))
        raise ParseError.new("unexpected token", self)
      end
      if(eql_lit?(ECMA262::ID_ELSE) and e = statement(var_env))
        ECMA262::StIf.new(cond, s, e)
      else
        ECMA262::StIf.new(cond, s, nil)
      end
    end
    # Tests next literals sequence is IterationStatement or not.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 12.6
    def iteration_statement(var_env)
      for_statement(var_env) or while_statement(var_env) or do_while_statement(var_env)
    end

    def while_statement(var_env)
      return nil unless eql_lit?(ECMA262::ID_WHILE)
      if eql_lit?(ECMA262::PUNC_LPARENTHESIS) and e=exp(var_env, {}) and eql_lit?(ECMA262::PUNC_RPARENTHESIS) and s=statement(var_env)
        ECMA262::StWhile.new(e, s)
      else
        raise ParseError.new("unexpected token", self)
      end
    end

    def do_while_statement(var_env)
      return nil unless eql_lit?(ECMA262::ID_DO)
      if s=statement(var_env) and eql_lit?(ECMA262::ID_WHILE) and eql_lit?(ECMA262::PUNC_LPARENTHESIS) and e=exp(var_env, {}) and eql_lit?(ECMA262::PUNC_RPARENTHESIS) and semicolon(var_env)
        ECMA262::StDoWhile.new(e, s)
      else
        raise ParseError.new("unexpected token", self)
      end
    end

    #12.6
    #
    # for ( ExpressionNoInopt ; Expressionopt ; Expressionopt ) Statement
    # for ( var VariableDeclarationListNoIn ; Expressionopt ; Expressionopt ) Statement
    # for ( LeftHandSideExpression in Expression ) Statement
    # for ( var VariableDeclarationNoIn in Expression ) Statement
    #
    def for_statement(var_env)
      return nil unless eql_lit?(ECMA262::ID_FOR)
      raise ParseError('unexpected token', self) unless eql_lit?(ECMA262::PUNC_LPARENTHESIS)
      eval_lit{
        # for(var i in a)
        if eql_lit?(ECMA262::ID_VAR)
          eval_lit{
            if v=var_decl(var_env, :no_in => true) and eql_lit?(ECMA262::ID_IN)
              if e=exp(var_env, {}) and eql_lit?(ECMA262::PUNC_RPARENTHESIS) and s = statement(var_env)
                #10.5
                var_env.record.create_mutable_binding(v[0], nil)
                var_env.record.set_mutable_binding(v[0], :undefined, nil)
                ECMA262::StForInVar.new(var_env, v, e, s)
              else
                raise ParseError.new("unexpected token", self)
              end
            end
          } or eval_lit {
            # for(var i ; cond ; exp)
            if vl=var_decl_list(var_env, :no_in =>true) and s1=eql_lit?(ECMA262::PUNC_SEMICOLON) and (e=exp(var_env, {})||true) and s2=eql_lit?(ECMA262::PUNC_SEMICOLON) and (e2=exp(var_env, {})||true) and eql_lit?(ECMA262::PUNC_RPARENTHESIS) and s=statement(var_env)
              e = nil if e == true
              e2 = nil if e2 == true
              #10.5
              vl.each do |v|
                dn = v[0]
                var_env.record.create_mutable_binding(dn, nil)
                var_env.record.set_mutable_binding(dn, :undefined, nil)
              end
              ECMA262::StForVar.new(var_env, vl, e, e2, s)
            else
              if !s1
                raise ParseError.new("no semicolon", self)
              elsif !s2
                raise ParseError.new("no semicolon", self)
              else
                raise ParseError.new("unexpected token", self)
              end
            end
          }
        else # => for(i in exp) / for(i ; cond; exp)
          eval_lit{
            # for(i in exp)
            if v=left_hand_side_exp(var_env) and eql_lit?(ECMA262::ID_IN)
              if e=exp(var_env, {}) and eql_lit?(ECMA262::PUNC_RPARENTHESIS) and s=statement(var_env)
                ECMA262::StForIn.new(v, e, s)
              else
                raise ParseError.new("unexpected token", self)
              end
            end
          } or eval_lit{
            # for(i ; cond; exp)
            if (v=exp(var_env, :no_in => true) || true) and s1=eql_lit?(ECMA262::PUNC_SEMICOLON) and (e=exp(var_env, {}) || true) and s2=eql_lit?(ECMA262::PUNC_SEMICOLON) and (e2=exp(var_env, {})||true) and eql_lit?(ECMA262::PUNC_RPARENTHESIS) and s=statement(var_env)
              v = nil if v == true
              e = nil if e == true
              e2 = nil if e2 == true
              ECMA262::StFor.new(v, e, e2, s)
            else
              raise ParseError.new("unexpected token", self)
            end
          }
        end
      }
    end
    private :while_statement, :do_while_statement, :for_statement

    # Tests next literals sequence is ContinueStatement or not.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 12.7
    def continue_statement(var_env)
      return nil unless eql_lit?(ECMA262::ID_CONTINUE)

      if semicolon(var_env)
        ECMA262::StContinue.new
      elsif e=identifier(var_env) and semicolon(var_env)
        ECMA262::StContinue.new(e)
      else
        if e
          raise ParseError.new("no semicolon at end of continue statement", self)
        else
          raise ParseError.new("unexpected token", self)
        end
      end
    end

    # Tests next literals sequence is BreakStatement or not.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 12.8
    def break_statement(var_env)
      return nil unless eql_lit?(ECMA262::ID_BREAK)

      if semicolon(var_env)
        ECMA262::StBreak.new
      elsif e=identifier(var_env) and semicolon(var_env)
        ECMA262::StBreak.new(e)
      else
        if e
          raise ParseError.new("no semicolon at end of break statement", self)
        else
          raise ParseError.new("unexpected token", self)
        end
      end
    end
    # Tests next literals sequence is ReturnStatement or not.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 12.9
    def return_statement(var_env)
      return nil unless eql_lit?(ECMA262::ID_RETURN)

      if semicolon(var_env)
        ECMA262::StReturn.new
      elsif e=exp(var_env, {}) and semicolon(var_env)
        ECMA262::StReturn.new(e)
      else
        raise ParseError.new("unexpected token", self)
      end
    end
    # Tests next literals sequence is WithStatement or not.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 12.10
    def with_statement(var_env)
      return nil unless eql_lit?(ECMA262::ID_WITH)

      if eql_lit?(ECMA262::PUNC_LPARENTHESIS) and e=exp(var_env, {}) and eql_lit?(ECMA262::PUNC_RPARENTHESIS) and s=statement(var_env)
        ECMA262::StWith.new(var_env, e, s)
      else
        raise ParseError.new("unexpected token", self)
      end
    end
    # Tests next literals sequence is SwitchStatement or not.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 12.11
    def switch_statement(var_env)
      return nil unless eql_lit?(ECMA262::ID_SWITCH)

      if eql_lit?(ECMA262::PUNC_LPARENTHESIS) and e=exp(var_env, {}) and eql_lit?(ECMA262::PUNC_RPARENTHESIS) and  c = case_block(var_env)
        ECMA262::StSwitch.new(e, c)
      else
        raise ParseError.new("unexpected token", self)
      end
    end

    def case_block(var_env)
      return nil unless eql_lit?(ECMA262::PUNC_LCURLYBRAC)
      _case_block = []
      while true
        if eql_lit?(ECMA262::ID_CASE)
          if e = exp(var_env, {}) and eql_lit?(ECMA262::PUNC_COLON)
            sl = statement_list(var_env)
            _case_block.push [e, sl]
          else
            raise ParseError.new("unexpected token", self)
          end
        elsif eql_lit?(ECMA262::ID_DEFAULT)
          if eql_lit?(ECMA262::PUNC_COLON)
            sl = statement_list(var_env)
            _case_block.push [nil, sl]
          else
            raise ParseError.new("unexpected token", self)
          end
        elsif eql_lit?(ECMA262::PUNC_RCURLYBRAC)
          break
        end
      end
      _case_block
    end
    private :case_block

    # Tests next literals sequence is LabelledStatement or not.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 12.12
    def labelled_statement(var_env)
      eval_lit {
        if i=identifier(var_env) and s1=eql_lit?(ECMA262::PUNC_COLON)
          if s=statement(var_env)
            ECMA262::StLabelled.new(i, s)
          else
            raise ParseError.new("unexpected token", self)
          end
        else
          nil
        end
      }
    end
    # Tests next literals sequence is ThrowStatement or not.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 12.13
    def throw_statement(var_env)
      return nil unless eql_lit?(ECMA262::ID_THROW)

      if semicolon(var_env)
        raise ParseError.new("no line terminator here", self)
      elsif e=exp(var_env, {}) and semi = semicolon(var_env)
        ECMA262::StThrow.new(e)
      else
        if e
          raise ParseError.new("no semicolon at end of throw statement", self)
        else
          raise ParseError.new("unexpected token", self)
        end
      end
    end
    # Tests next literals sequence is TryStatement or not.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 12.14
    def try_statement(var_env)
      return nil unless eql_lit?(ECMA262::ID_TRY)
      #
      # The catch argument var_env must be executable lexical environment.
      # See compress_var
      #
      t = block(var_env)
      return nil unless t

      c = try_catch(var_env)
      f = try_finally(var_env)
      ECMA262::StTry.new(var_env, t, c, f)
    end
    # 12.14
    #
    # Catch :
    # catch ( Identifier ) Block
    #
    # return [identigier, block]
    #
    def try_catch(var_env)
      return nil unless eql_lit?(ECMA262::ID_CATCH)

      if eql_lit?(ECMA262::PUNC_LPARENTHESIS) and i=identifier(var_env) and eql_lit?(ECMA262::PUNC_RPARENTHESIS) and b=block(var_env)
        new_var_env = ECMA262::LexEnv.new(outer: var_env)
        ECMA262::StTryCatch.new(new_var_env, i, b)
      else
        raise ParseError.new("unexpected token", self)
      end
    end

    def try_finally(var_env)
      return nil unless eql_lit?(ECMA262::ID_FINALLY)
      b = block(var_env)
      raise ParseError.new("unexpected token", self) if b.nil?
      b
    end

    private :try_catch, :try_finally

    # Tests next literals sequence is DebuggerStatement or not.
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 12.15
    def debugger_statement(var_env)
      return nil unless eql_lit?(ECMA262::ID_DEBUGGER)
      if semicolon(var_env)
        ECMA262::StDebugger.new
      else
        raise ParseError.new("no semicolon at end of debugger statement", self)
      end
    end

  end
end


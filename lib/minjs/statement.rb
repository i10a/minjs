module Minjs
  #
  # 12
  #
  module Statement
    #
    # check next literal is ';' or '}' or LT
    #
    def semicolon(lex, context)
      if a=lex.match_lit(ECMA262::PUNC_SEMICOLON)
        a
      elsif a=lex.match_lit(ECMA262::PUNC_RCURLYBRAC)
        lex.rewind_pos
        a
      elsif a=lex.match_lit(ECMA262::LIT_LINE_FEED, :nolt => true)
        a
      else
        nil
      end
    end

    #12
    def statement(lex, context)
      [:block,
       :empty_statement,
       :var_statement,
       :if_statement,
       :iteration_statement,
       :continue_statement,
       :break_statement,
       :return_statement,
       :with_statement,
       :labelled_statement,
       :switch_statement,
       :throw_statement,
       :try_statement,
       :debugger_statement,
       :exp_statement,
      ].each do |f|
        puts "* checking #{f.to_s}" if @debug
        t = lex.eval_lit {
          __send__(f, lex, context)
        }
        return t if t
      end
      nil
    end
    #
    #12.1
    # block
    def block(lex, context)
      return nil unless lex.match_lit(ECMA262::PUNC_LCURLYBRAC)
      if lex.match_lit(ECMA262::PUNC_RCURLYBRAC)
        return ECMA262::StBlock.new(ECMA262::StList.new([]))
      end
      lex.eval_lit {
        if s = statement_list(lex, context) and lex.match_lit(ECMA262::PUNC_RCURLYBRAC)
          ECMA262::StBlock.new(s)
        else
          if s
            lex.debug_lit
            raise 'no "}" end of block'
          else
            lex.debug_lit
            raise "bad block"
          end
        end
      }
    end

    def statement_list(lex, context)
      lex.eval_lit {
        t = []
        while !lex.eof?
          if s = statement(lex, context)
            t.push(s)
          else
            break
          end
        end
        ECMA262::StList.new(t)
      }
    end
    #
    #12.2
    # variable_statement
    #
    def var_statement(lex, context)
      raise 'error' if context.nil?
      return nil unless lex.match_lit(ECMA262::ID_VAR)
      lex.eval_lit {
        if vl = var_decl_list(lex, context, {}) and semicolon(lex, context)
          #10.5
          vl.each do |v|
            dn = v[0]
            context.var_env.record.create_mutable_binding(dn, nil)
            context.var_env.record.set_mutable_binding(dn, :undefined, nil)
          end
          ECMA262::StVar.new(context, vl)
        else
          lex.debug_lit
          raise ParseError.new("var_statement")
        end
      }
    end

    def var_decl_list(lex, context, options)
      lex.eval_lit {
        a = var_decl(lex, context, options)
        next nil if !a

        if lex.match_lit(ECMA262::PUNC_COMMA) and b = var_decl_list(lex, context, options)
          next [a] + b
        else
          next [a]
        end
      }
    end

    def var_decl(lex, context, options)
      lex.eval_lit {
        a = lex.fwd_lit
        if !a
          nil
        elsif !a.kind_of?(ECMA262::IdentifierName)
          nil
        else
          b = initialiser(lex, context, options)
          [a, b]
        end
      }
    end

    def initialiser(lex, context, options)
      if lex.match_lit(ECMA262::PUNC_LET) and a = assignment_exp(lex, context, options)
        return a
      end

      nil
    end
    #
    #12.3
    #
    def empty_statement(lex, context)
      lex.eval_lit {
        t = lex.fwd_lit
        if t.nil?
          ECMA262::StEmpty.new()
        elsif t == ECMA262::PUNC_SEMICOLON
          ECMA262::StEmpty.new()
        elsif t == ECMA262::LIT_LINE_FEED
          ECMA262::StEmpty.new()
        else
          nil
        end
      }
    end
    #
    #12.4
    #
    def exp_statement(lex, context)
      return false if lex.next_lit == ECMA262::PUNC_LCURLYBRAC
      return false if lex.next_lit == ECMA262::ID_FUNCTION
      lex.eval_lit{
        if a=exp(lex, context, {}) and semicolon(lex, context)
          ECMA262::StExp.new(a)
        else
          nil
        end
      }
    end
    #
    #12.5
    #
    def if_statement(lex, context)
      lex.eval_lit {
        unless lex.match_lit(ECMA262::ID_IF) and lex.match_lit(ECMA262::PUNC_LPARENTHESIS) and cond=exp(lex, context, {}) and lex.match_lit(ECMA262::PUNC_RPARENTHESIS) and s=statement(lex, context)
          next nil
        end
        if lex.match_lit(ECMA262::ID_ELSE) and e=statement(lex, context)
          ECMA262::StIf.new(cond, s, e)
        else
          ECMA262::StIf.new(cond, s, nil)
        end
      }
    end
    #
    # 12.6
    #
    def iteration_statement(lex, context)
      for_statement(lex, context) or while_statement(lex, context) or do_while_statement(lex, context)
    end

    def while_statement(lex, context)
      return nil unless lex.match_lit(ECMA262::ID_WHILE)
      if lex.match_lit(ECMA262::PUNC_LPARENTHESIS) and e=exp(lex, context, {}) and lex.match_lit(ECMA262::PUNC_RPARENTHESIS) and s=statement(lex, context)
        ECMA262::StWhile.new(e, s)
      else
        lex.debug_lit
        raise ParseError.new("while_statement")
      end
    end

    def do_while_statement(lex, context)
      return nil unless lex.match_lit(ECMA262::ID_DO)
      if s=statement(lex, context) and lex.match_lit(ECMA262::ID_WHILE) and lex.match_lit(ECMA262::PUNC_LPARENTHESIS) and e=exp(lex, context, {}) and lex.match_lit(ECMA262::PUNC_RPARENTHESIS) and semicolon(lex, context)
        ECMA262::StDoWhile.new(e, s)
      else
        lex.debug_lit
        raise ParseError.new("do_while_statement")
      end
    end

    def for_statement(lex, context)
      return nil unless lex.match_lit(ECMA262::ID_FOR)
      lex.eval_lit{
        # for(var i in a)
        next nil unless lex.match_lit(ECMA262::PUNC_LPARENTHESIS)
        if lex.match_lit(ECMA262::ID_VAR) and v=var_decl(lex, context, :no_in => true) and lex.match_lit(ECMA262::ID_IN) and e=exp(lex, context, {}) and lex.match_lit(ECMA262::PUNC_RPARENTHESIS) and s=statement(lex, context)
          #10.5
          context.var_env.record.create_mutable_binding(v[0], nil)
          context.var_env.record.set_mutable_binding(v[0], :undefined, nil)
          ECMA262::StForInVar.new(context, v, e, s)
        else
          nil
        end
      } or lex.eval_lit {
        # for(var i ; cond ; exp)
        next nil unless lex.match_lit(ECMA262::PUNC_LPARENTHESIS)
        if lex.match_lit(ECMA262::ID_VAR) and vl=var_decl_list(lex, context, :no_in =>true) and lex.match_lit(ECMA262::PUNC_SEMICOLON) and (e=exp(lex, context, {})||true) and lex.match_lit(ECMA262::PUNC_SEMICOLON) and (e2=exp(lex, context, {})||true) and lex.match_lit(ECMA262::PUNC_RPARENTHESIS) and s=statement(lex, context)
          e = ECMA262::ExpEmpty.new if e == true
          e2 = ECMA262::ExpEmpty.new if e2 == true
          #10.5
          vl.each do |v|
            dn = v[0]
            context.var_env.record.create_mutable_binding(dn, nil)
            context.var_env.record.set_mutable_binding(dn, :undefined, nil)
          end
          ECMA262::StForVar.new(context, vl, e, e2, s)
        else
          nil
        end
      } or lex.eval_lit{
        # for(i in exp)
        next nil unless lex.match_lit(ECMA262::PUNC_LPARENTHESIS)
        if v=left_hand_side_exp(lex, context, {}) and lex.match_lit(ECMA262::ID_IN) and e=exp(lex, context, {}) and lex.match_lit(ECMA262::PUNC_RPARENTHESIS) and s=statement(lex, context)
          ECMA262::StForIn.new(v, e, s)
        else
          nil
        end
      } or lex.eval_lit{
        # for(i ; cond; exp)
        next nil unless lex.match_lit(ECMA262::PUNC_LPARENTHESIS)
        if (v=exp(lex, context, :no_in => true) || true) and lex.match_lit(ECMA262::PUNC_SEMICOLON) and (e=exp(lex, context, {}) || true) and lex.match_lit(ECMA262::PUNC_SEMICOLON) and (e2=exp(lex, context, {})||true) and lex.match_lit(ECMA262::PUNC_RPARENTHESIS) and s=statement(lex, context)
          v = ECMA262::ExpEmpty.new if v == true
          e = ECMA262::ExpEmpty.new if e == true
          e2 = ECMA262::ExpEmpty.new if e2 == true
          ECMA262::StFor.new(v, e, e2, s)
        else
          nil
        end
      }
    end
    #
    # 12.7
    #
    def continue_statement(lex, context)
      return nil unless lex.match_lit(ECMA262::ID_CONTINUE)
      lex.eval_lit {
        if semicolon(lex, context)
          ECMA262::StContinue.new
        elsif e=exp(lex, context, {}) and semicolon(lex, context)
          ECMA262::StContinue.new(e)
        end
      }
    end
    #
    # 12.8
    #
    def break_statement(lex, context)
      return nil unless lex.match_lit(ECMA262::ID_BREAK)
      lex.eval_lit {
        if semicolon(lex, context)
          ECMA262::StBreak.new
        elsif e=exp(lex, context, {}) and semicolon(lex, context)
          ECMA262::StBreak.new(e)
        end
      }
    end
    #
    # 12.9
    #
    def return_statement(lex, context)
      return nil unless lex.match_lit(ECMA262::ID_RETURN)
      lex.eval_lit {
        if semicolon(lex, context)
          ECMA262::StReturn.new
        elsif e=exp(lex, context, {}) and semicolon(lex, context)
          ECMA262::StReturn.new(e)
        else
          nil
        end
      }
    end
    #
    # 12.10
    #
    def with_statement(lex, context)
      return nil unless lex.match_lit(ECMA262::ID_WITH)
      lex.eval_lit {
        if lex.match_lit(ECMA262::PUNC_LPARENTHESIS) and e=exp(lex, context, {}) and lex.match_lit(ECMA262::PUNC_RPARENTHESIS) and s=statement(lex, context)
          ECMA262::StWith.new(e, s)
        else
          lex.debug_lit
          raise ParseError.new("switch_statement")
        end
      }
    end
    #
    # 12.11
    #
    def switch_statement(lex, context)
      return nil unless lex.match_lit(ECMA262::ID_SWITCH)
      lex.eval_lit {
        if lex.match_lit(ECMA262::PUNC_LPARENTHESIS) and e=exp(lex, context, {}) and lex.match_lit(ECMA262::PUNC_RPARENTHESIS) and  c = case_block(lex, context)
          ECMA262::StSwitch.new(e, c)
        else
          lex.debug_lit
          raise ParseError.new("switch_statement")
        end
      }
    end

    def case_block(lex, context)
      return nil unless lex.match_lit(ECMA262::PUNC_LCURLYBRAC)
      _case_block = []
      while true
        t = lex.eval_lit{
          break unless lex.match_lit(ECMA262::ID_CASE) and e=exp(lex, context, {}) and lex.match_lit(ECMA262::PUNC_COLON)
          sl = statement_list(lex, context)
          [e, sl]
        } || lex.eval_lit{
          break unless lex.match_lit(ECMA262::ID_DEFAULT) and lex.match_lit(ECMA262::PUNC_COLON)
          sl = statement_list(lex, context)
          [nil, sl]
        }
        break if t.nil?
        _case_block.push(t)
      end
      return nil unless lex.match_lit(ECMA262::PUNC_RCURLYBRAC)
      _case_block
    end
    #
    # 12.12
    #
    def labelled_statement(lex, context)
      lex.eval_lit {
        if i=identifier(lex, context) and lex.match_lit(ECMA262::PUNC_COLON) and s=statement(lex, context)
          ECMA262::StLabelled.new(i, s)
        else
          nil
        end
      }
    end
    #
    # 12.13
    #
    def throw_statement(lex, context)
      return nil unless lex.match_lit(ECMA262::ID_THROW)
      lex.eval_lit{
        if e=exp(lex, context, {}) and semicolon(lex, context)
          ECMA262::StThrow.new(e)
        else
          lex.debug_lit
          raise ParseError.new("throw_statement")
        end
      }
    end
    #
    # 12.14
    #
    def try_statement(lex, context)
      return nil unless lex.match_lit(ECMA262::ID_TRY)
      lex.eval_lit {
        t = block(lex, context)
        break nil unless t

        lex.eval_lit{
          c = try_catch(lex, context)
          break nil unless c

          f = try_finally(lex, context)
          ECMA262::StTry.new(t, c, f)
        } || lex.eval_lit{
          f = try_finally(lex, context)
          break nil unless f
          ECMA262::StTry.new(t, nil, f)
        }
      }
    end
    def try_catch(lex, context)
      return nil unless lex.match_lit(ECMA262::ID_CATCH)
      if lex.match_lit(ECMA262::PUNC_LPARENTHESIS) and i=identifier(lex, context) and lex.match_lit(ECMA262::PUNC_RPARENTHESIS) and b=block(lex, context)
        [i, b]
      else
        nil
      end
    end

    def try_finally(lex, context)
      return nil unless lex.match_lit(ECMA262::ID_FINALLY)
      block(lex, context)
    end

    #
    # 12.15
    #
    def debugger_statement(lex, context)
      if lex.match_lit(ECMA262::ID_DEBUGGER) and semicolon(lex, context)
        t = ECMA262::StDebugger.new
      end
    end

  end
end


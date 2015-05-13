module Minjs
  module Exp
    #
    # Primary Expressions
    # 11.1
    #
    def primary_exp(lex, context, options)
      STDERR.puts "*** primary_exp" if @debug
      lex.debug_lit if @debug
      #STDERR.puts caller if @debug
      #this
      if lex.match_lit(ECMA262::ID_THIS)
      STDERR.puts "*** primary_exp => this" if @debug
        return ECMA262::ID_THIS
      end
      # (exp)
      if lex.match_lit(ECMA262::PUNC_LPARENTHESIS)
        if a=exp(lex, context, options) and lex.match_lit(ECMA262::PUNC_RPARENTHESIS)
          STDERR.puts "*** primary_exp => ()" if @debug
          return ECMA262::ExpParen.new(a)
        else
          raise ParseError.new("no `)' at end of expression", lex)
        end
      end

      # identifier || literal || array_literal || object_literal
      t = lex.eval_lit {
        identifier(lex, context)
      } || lex.eval_lit {
        literal(lex, context)
      } || lex.eval_lit {
        array_literal(lex, context, options)
      } || lex.eval_lit {
        object_literal(lex, context, options)
      }
      STDERR.puts "*** primary_exp => #{t}" if @debug
      t
    end

    #
    # 11.1.2
    #
    def identifier(lex, context)
      lex.eval_lit {
        if (a = lex.fwd_lit).kind_of? ECMA262::IdentifierName and !a.reserved?
          a.context = context
          a
        else
          nil
        end
      }
    end

    #
    # 11.1.4
    #
    def array_literal(lex, context, options)
      return nil unless lex.match_lit(ECMA262::PUNC_LSQBRAC)
      t = []
      lex.eval_lit {
        while true
          if lex.match_lit(ECMA262::PUNC_COMMA)
            t.push(nil)
          elsif lex.match_lit(ECMA262::PUNC_RSQBRAC)
            break
          elsif a = assignment_exp(lex, context, {})
            t.push(a)
            lex.match_lit(ECMA262::PUNC_COMMA)
          else
            raise ParseError.new("no `]' end of array", lex)
          end
        end
        ECMA262::ECMA262Array.new(t)
      }
    end
    #
    # 11.1.5
    #
    def object_literal(lex, context, options)
      return nil unless lex.match_lit(ECMA262::PUNC_LCURLYBRAC)
      lex.eval_lit {
        if lex.match_lit(ECMA262::PUNC_RCURLYBRAC)
          next ECMA262::ECMA262Object.new([])
        end
        if h=property_name_and_value_list(lex, context, options)
          ECMA262::ECMA262Object.new(h)
        else
          raise ParseError.new("no `}' end of object", lex)
        end
      }
    end

    #
    # name: exp
    # get name(){funcbody}
    # set name(args){funcbody}
    #
    def property_name_and_value_list(lex, context, options)
      lex.eval_lit{
        h = []
        while !lex.eof?
          if lex.match_lit(ECMA262::PUNC_RCURLYBRAC)
            break
          end
          lex.eval_lit{
            if lex.match_lit(ECMA262::ID_GET) and a=property_name(lex, context) and lex.match_lit(ECMA262::PUNC_LPARENTHESIS) and lex.match_lit(ECMA262::PUNC_RPARENTHESIS) and lex.match_lit(ECMA262::PUNC_LCURLYBRAC) and b=func_body(lex, context) and lex.match_lit(ECMA262::PUNC_RCURLYBRAC)
              h.push([a, ECMA262::StFunc.new(context, ECMA262::ID_GET, [], b, :getter => true)])
            elsif lex.match_lit(ECMA262::ID_SET) and a=property_name(lex, context) and lex.match_lit(ECMA262::PUNC_LPARENTHESIS) and arg=property_set_parameter_list(lex, context) and lex.match_lit(ECMA262::PUNC_RPARENTHESIS) and lex.match_lit(ECMA262::PUNC_LCURLYBRAC) and b=func_body(lex, context) and lex.match_lit(ECMA262::PUNC_RCURLYBRAC)
              h.push([a, ECMA262::StFunc.new(context, ECMA262::ID_SET, arg, b, :setter => true)])
            else
              nil
            end
          } or lex.eval_lit{
            a=property_name(lex, context) and lex.match_lit(ECMA262::PUNC_COLON) and b=assignment_exp(lex, context, options)
            h.push([a, b])
          }

          if lex.match_lit(ECMA262::PUNC_COMMA)
            break if lex.match_lit(ECMA262::PUNC_RCURLYBRAC)
          elsif lex.match_lit(ECMA262::PUNC_RCURLYBRAC)
            break
          else
            raise ParseError.new("no `}' end of object", lex)
          end
        end
        h
      }
    end

    def property_name(lex, context)
      lex.eval_lit {
        a = lex.fwd_lit
        if a.kind_of?(ECMA262::ECMA262String)
          a
        elsif a.kind_of?(ECMA262::IdentifierName)
          ECMA262::ECMA262String.new(a.to_js)
        elsif a.kind_of?(ECMA262::ECMA262Numeric)
          a
        else
          nil
        end
      }
    end

    def property_set_parameter_list(lex, context)
      lex.eval_lit {
        a = lex.fwd_lit
        if a.kind_of?(ECMA262::IdentifierName) and !a.reserved?
          [a]
        else
          nil
        end
      }
    end

    #
    # 11.2
    #
    def left_hand_side_exp(lex, context, options)
      STDERR.puts "*** left_hand_side_exp" if @debug
      lex.debug_lit if @debug

      t = lex.eval_lit{
        call_exp(lex, context, options)
      } || lex.eval_lit{
        new_exp(lex, context, options)
      }
      STDERR.puts "*** left_hand_side_exp => #{t}" if @debug
      t
    end

    def new_exp(lex, context, options)
      lex.eval_lit{
        if lex.match_lit(ECMA262::ID_NEW) and a=new_exp(lex, context, options)
          ECMA262::ExpNew.new(a, nil)
        else
          nil
        end
      } or lex.eval_lit{
        member_exp(lex, context, options)
      }
    end

    #
    # call
    #
    # member_exp arguments
    #
    # call_exp arguments
    # call_exp [exp]
    # call_exp . identifier_name
    #
    #
    def call_exp(lex, context, options)
      a = lex.eval_lit{
        if f = member_exp(lex, context, options)
          if b = arguments(lex, context, options)
            ECMA262::ExpCall.new(f, b)
          else
            f
          end
        else
          nil
        end
      }
      return nil if a.nil?

      t = a

      lex.eval_lit{
        while true
          if b=arguments(lex, context, options)
            t = ECMA262::ExpCall.new(t, b)
          elsif lex.match_lit(ECMA262::PUNC_LSQBRAC) and b=exp(lex, context, options) and lex.match_lit(ECMA262::PUNC_RSQBRAC)
            t = ECMA262::ExpPropBrac.new(t, b)
          elsif lex.match_lit(ECMA262::PUNC_PERIOD) and (b=lex.fwd_lit()).kind_of?(ECMA262::IdentifierName)
            t = ECMA262::ExpProp.new(t, b)
          else
            break
          end
        end
        t
      } or a
    end

    #
    # member_exp
    #  primary_exp
    #  function_exp
    #  new member_exp arguments
    #
    #  member_exp[exp]
    #  member_exp.identifier_name #prop(a,b)
    #
    def member_exp(lex, context, options)
      a = lex.eval_lit {
        primary_exp(lex, context, options)
      } || lex.eval_lit {
        func_exp(lex, context)
      } || lex.eval_lit {
        if lex.match_lit(ECMA262::ID_NEW) and a=member_exp(lex, context, options) and b=arguments(lex, context, options)
          ECMA262::ExpNew.new(a, b)
        else
          nil
        end
      }
      return nil if a.nil?

      t = a

      lex.eval_lit {
        while true
          if lex.match_lit(ECMA262::PUNC_LSQBRAC) and b=exp(lex, context, options) and lex.match_lit(ECMA262::PUNC_RSQBRAC)
            t = ECMA262::ExpPropBrac.new(t, b)
          elsif lex.match_lit(ECMA262::PUNC_PERIOD) and (b=lex.fwd_lit()).kind_of?(ECMA262::IdentifierName)
            t = ECMA262::ExpProp.new(t, b)
          else
            break
          end
        end
        t
      } or a
    end

    def arguments(lex, context, options)
      lex.eval_lit{
        return nil if lex.match_lit(ECMA262::PUNC_LPARENTHESIS).nil?
        next [] if lex.match_lit(ECMA262::PUNC_RPARENTHESIS)
        args = []
        while true
          if t = assignment_exp(lex, context, options)
            args.push(t)
          else
            return
          end
          if lex.match_lit(ECMA262::PUNC_COMMA)
            ;
          elsif lex.match_lit(ECMA262::PUNC_RPARENTHESIS)
            break
          else
            return
          end
        end
        args
      }
    end
    #
    # 11.3
    #
    def postfix_exp(lex, context, options)
      STDERR.puts "*** postfix_exp" if @debug
      lex.debug_lit if @debug

      t = lex.eval_lit{
        a = left_hand_side_exp(lex, context, options)
        return nil if a.nil?
        if punc = (lex.match_lit(ECMA262::PUNC_INC, :nolt => true) ||
                   lex.match_lit(ECMA262::PUNC_DEC, :nolt => true))
          if punc == ECMA262::PUNC_INC
            ECMA262::ExpPostInc.new(a)
          else
            ECMA262::ExpPostDec.new(a)
          end
        else
          a
        end
      }
      STDERR.puts "*** postfix_exp => #{t}" if @debug
      t
    end

    #
    # 11.4
    #
    def unary_exp(lex, context, options)
      next_exp = :postfix_exp
      lex.eval_lit{
        if punc = (lex.match_lit(ECMA262::ID_DELETE) ||
                   lex.match_lit(ECMA262::ID_VOID) ||
                   lex.match_lit(ECMA262::ID_TYPEOF) ||
                   lex.match_lit(ECMA262::PUNC_INC) ||
                   lex.match_lit(ECMA262::PUNC_DEC) ||
                   lex.match_lit(ECMA262::PUNC_ADD) ||
                   lex.match_lit(ECMA262::PUNC_SUB) ||
                   lex.match_lit(ECMA262::PUNC_NOT) ||
                   lex.match_lit(ECMA262::PUNC_LNOT)) and a = unary_exp(lex, context, options)
          if punc.val == :delete
            ECMA262::ExpDelete.new(a)
          elsif punc.val == :void
            ECMA262::ExpVoid.new(a)
          elsif punc.val == :typeof
            ECMA262::ExpTypeof.new(a)
          elsif punc == ECMA262::PUNC_INC
            ECMA262::ExpPreInc.new(a)
          elsif punc == ECMA262::PUNC_DEC
            ECMA262::ExpPreDec.new(a)
          elsif punc == ECMA262::PUNC_ADD
            ECMA262::ExpPositive.new(a)
          elsif punc == ECMA262::PUNC_SUB
            ECMA262::ExpNegative.new(a)
          elsif punc == ECMA262::PUNC_NOT
            ECMA262::ExpBitwiseNot.new(a)
          elsif punc == ECMA262::PUNC_LNOT
            ECMA262::ExpLogicalNot.new(a)
          end
        end
      } || lex.eval_lit{
        __send__(next_exp, lex, context, options)
      }
    end

    #
    # 11.5
    #
    def multiplicative_exp(lex, context, options)
      next_exp = :unary_exp
      lex.eval_lit {
        a = __send__(next_exp, lex, context, options)
        next nil if !a
        t = a
        while punc = lex.match_lit(ECMA262::PUNC_MUL) ||
                     lex.match_lit(ECMA262::PUNC_DIV, :hint => :div) ||
                     lex.match_lit(ECMA262::PUNC_MOD)

          if b = __send__(next_exp, lex, context, options)
            if punc == ECMA262::PUNC_MUL
              t = ECMA262::ExpMul.new(t, b)
            elsif punc == ECMA262::PUNC_DIV
              t = ECMA262::ExpDiv.new(t, b)
            else
              t = ECMA262::ExpMod.new(t, b)
            end
          else
            break
          end
        end
        t
      }
    end

    #
    # 11.6
    #
    def additive_exp(lex, context, options)
      next_exp = :multiplicative_exp
      lex.eval_lit {
        a = __send__(next_exp, lex, context, options)
        next nil if !a

        t = a
        while punc = lex.match_lit(ECMA262::PUNC_ADD) || lex.match_lit(ECMA262::PUNC_SUB)
          if b = __send__(next_exp, lex, context, options)
            if punc == ECMA262::PUNC_ADD
              t = ECMA262::ExpAdd.new(t, b)
            else
              t = ECMA262::ExpSub.new(t, b)
            end
          else
            break
          end
        end

        t
      }
    end
    #
    # 11.7
    def shift_exp(lex, context, options)
      next_exp = :additive_exp
      lex.eval_lit {
        a = __send__(next_exp, lex, context, options)
        next nil if !a

        t = a
        while punc = lex.match_lit(ECMA262::PUNC_LSHIFT) ||
                     lex.match_lit(ECMA262::PUNC_RSHIFT) ||
                     lex.match_lit(ECMA262::PUNC_URSHIFT)
          if b = __send__(next_exp, lex, context, options)
            if punc == ECMA262::PUNC_LSHIFT
              t = ECMA262::ExpLShift.new(t, b)
            elsif punc == ECMA262::PUNC_RSHIFT
              t = ECMA262::ExpRShift.new(t, b)
            elsif punc == ECMA262::PUNC_URSHIFT
              t = ECMA262::ExpURShift.new(t, b)
            end
          else
            break
          end
        end
        t
      }
    end
    #
    #
    # 11.8
    #
    def relational_exp(lex, context, options)
      lex.eval_lit {
        a = shift_exp(lex, context, options)
        next nil if !a

        t = a
        while (punc = lex.match_lit(ECMA262::PUNC_LT) || lex.match_lit(ECMA262::PUNC_GT) ||
                      lex.match_lit(ECMA262::PUNC_LTEQ) || lex.match_lit(ECMA262::PUNC_GTEQ) ||
                      lex.match_lit(ECMA262::ID_INSTANCEOF) || (!options[:no_in] && lex.match_lit(ECMA262::ID_IN)))
          if b = shift_exp(lex, context, options)
            if punc == ECMA262::PUNC_LT
              t = ECMA262::ExpLt.new(t, b)
            elsif punc == ECMA262::PUNC_GT
              t = ECMA262::ExpGt.new(t, b)
            elsif punc == ECMA262::PUNC_LTEQ
              t = ECMA262::ExpLtEq.new(t, b)
            elsif punc == ECMA262::PUNC_GTEQ
              t = ECMA262::ExpGtEq.new(t, b)
            elsif punc.val == :instanceof
              t = ECMA262::ExpInstanceOf.new(t, b)
            elsif !options[:no_in] and punc.val == :in
              t = ECMA262::ExpIn.new(t, b)
            else
            end
          else
            break
          end
        end

        t
      }
    end
    #
    #
    # 11.9
    # a == b
    # a != b
    # a === b
    # a !== b
    #
    def equality_exp(lex, context, options)
      next_exp = :relational_exp
      lex.eval_lit {
        a = __send__(next_exp, lex, context, options)
        next nil if !a

        t = a
        while punc = lex.match_lit(ECMA262::PUNC_EQ) ||
                     lex.match_lit(ECMA262::PUNC_NEQ) ||
                     lex.match_lit(ECMA262::PUNC_SEQ) ||
                     lex.match_lit(ECMA262::PUNC_SNEQ)
          if b = __send__(next_exp, lex, context, options)
            if punc == ECMA262::PUNC_EQ
              t = ECMA262::ExpEq.new(t, b)
            elsif punc == ECMA262::PUNC_NEQ
              t = ECMA262::ExpNotEq.new(t, b)
            elsif punc == ECMA262::PUNC_SEQ
              t = ECMA262::ExpStrictEq.new(t, b)
            elsif punc == ECMA262::PUNC_SNEQ
              t = ECMA262::ExpStrictNotEq.new(t, b)
            end
          else
            break
          end
        end

        t
      }
    end

    #
    # 11.10
    # a & b
    #
    def bitwise_and_exp(lex, context, options)
      next_exp = :equality_exp
      lex.eval_lit {
        a = __send__(next_exp, lex, context, options)
        next nil if !a

        t = a
        while punc = lex.match_lit(ECMA262::PUNC_AND)
          if b = __send__(next_exp, lex, context, options)
            t = ECMA262::ExpAnd.new(t, b)
          else
            break
          end
        end

        t
      }
    end

    #
    # a ^ b
    #
    def bitwise_xor_exp(lex, context, options)
      next_exp = :bitwise_and_exp
      lex.eval_lit {
        a = __send__(next_exp, lex, context, options)
        next nil if !a

        t = a
        while punc = lex.match_lit(ECMA262::PUNC_XOR)
          if b = __send__(next_exp, lex, context, options)
            t = ECMA262::ExpXor.new(t, b)
          else
            break
          end
        end

        t
      }
    end

    #
    # a | b
    #
    def bitwise_or_exp(lex, context, options)
      next_exp = :bitwise_xor_exp
      lex.eval_lit {
        a = __send__(next_exp, lex, context, options)
        next nil if !a

        t = a
        while punc = lex.match_lit(ECMA262::PUNC_OR)
          if b = __send__(next_exp, lex, context, options)
            t = ECMA262::ExpOr.new(t, b)
          else
            break
          end
        end

        t
      }
    end
    #
    # 11.11
    # a && b
    #
    def logical_and_exp(lex, context, options)
      next_exp = :bitwise_or_exp
      lex.eval_lit {
        a = __send__(next_exp, lex, context, options)
        next nil if !a

        t = a
        while punc = lex.match_lit(ECMA262::PUNC_LAND)
          if b = __send__(next_exp, lex, context, options)
            t = ECMA262::ExpLogicalAnd.new(t, b)
          else
            break
          end
        end

        t
      }
    end

    def logical_or_exp(lex, context, options)
      next_exp = :logical_and_exp
      lex.eval_lit {
        a = __send__(next_exp, lex, context, options)
        next nil if !a

        t = a
        while punc = lex.match_lit(ECMA262::PUNC_LOR)
          if b = __send__(next_exp, lex, context, options)
            t = ECMA262::ExpLogicalOr.new(t, b)
          else
            break
          end
        end

        t
      }
    end
    #
    # 11.12
    # a ? b : c
    #
    def cond_exp(lex, context, options)
      t = lex.eval_lit {
        a = logical_or_exp(lex, context, options)
        next nil if !a

        if lex.match_lit(ECMA262::PUNC_CONDIF) and b=assignment_exp(lex, context, options) and lex.match_lit(ECMA262::PUNC_CONDELSE) and c=assignment_exp(lex, context, options)
          ECMA262::ExpCond.new(a, b, c)
        else
          a
        end
      }
      t
    end
    #
    #11.13
    #
    def assignment_exp(lex, context, options)
      STDERR.puts "*** assignment_exp" if @debug
      lex.debug_lit if @debug
      left_hand = nil
      t = cond_exp(lex, context, options)
      return nil if t.nil?
      lex.eval_lit {
        left_hand = t
        punc = lex.next_lit
        if punc == ECMA262::PUNC_LET ||
           punc == ECMA262::PUNC_DIVLET ||
           punc == ECMA262::PUNC_MULLET ||
           punc == ECMA262::PUNC_MODLET ||
           punc == ECMA262::PUNC_ADDLET ||
           punc == ECMA262::PUNC_SUBLET ||
           punc == ECMA262::PUNC_LSHIFTLET ||
           punc == ECMA262::PUNC_RSHIFTLET ||
           punc == ECMA262::PUNC_URSHIFTLET ||
           punc == ECMA262::PUNC_ANDLET ||
           punc == ECMA262::PUNC_ORLET ||
           punc == ECMA262::PUNC_XORLET
          lex.fwd_lit
          if b = assignment_exp(lex, context, options)
            case punc
            when ECMA262::PUNC_LET
              ECMA262::ExpAssign.new(left_hand, b)
            when ECMA262::PUNC_DIVLET
              ECMA262::ExpDivAssign.new(left_hand, b)
            when ECMA262::PUNC_MULLET
              ECMA262::ExpMulAssign.new(left_hand, b)
            when ECMA262::PUNC_MODLET
              ECMA262::ExpModAssign.new(left_hand, b)
            when ECMA262::PUNC_ADDLET
              ECMA262::ExpAddAssign.new(left_hand, b)
            when ECMA262::PUNC_SUBLET
              ECMA262::ExpSubAssign.new(left_hand, b)
            when ECMA262::PUNC_LSHIFTLET
              ECMA262::ExpLShiftAssign.new(left_hand, b)
            when ECMA262::PUNC_RSHIFTLET
              ECMA262::ExpRShiftAssign.new(left_hand, b)
            when ECMA262::PUNC_URSHIFTLET
              ECMA262::ExpURShiftAssign.new(left_hand, b)
            when ECMA262::PUNC_ANDLET
              ECMA262::ExpAndAssign.new(left_hand, b)
            when ECMA262::PUNC_ORLET
              ECMA262::ExpOrAssign.new(left_hand, b)
            when ECMA262::PUNC_XORLET
              ECMA262::ExpXorAssign.new(left_hand, b)
            else
              raise "internal error"
            end
          else # some assignment operator presents but no assignment_expression => fail
            return nil
          end
        else
          t
        end
      }
    end

    #
    # 11.14
    #
    def exp(lex, context, options)
      lex.eval_lit{
        t = assignment_exp(lex, context, {:hint => :regexp}.merge(options))
        while punc = lex.match_lit(ECMA262::PUNC_COMMA)
          if b = assignment_exp(lex,context, {:hint => :regexp}.merge(options))
            t = ECMA262::ExpComma.new(t, b)
          else
            break
          end
        end
        t
      }
    end
  end
end

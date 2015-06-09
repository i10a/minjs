# coding: utf-8
module Minjs::Lex
  module Expression
    include Minjs
    # Tests next literal is PrimaryExpression or not.
    #
    # If literal is PrimaryExpression
    # return ECMA262::Base object and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @param context [Context] Lexical Environment
    #
    # @return [ECMA262::ECMA262Object] expression
    #
    # @see ECMA262 11.1
    def primary_exp(context)
      @logger.debug "*** primary_exp"

      if lex.eql_lit?(ECMA262::ID_THIS)
        @logger.debug "*** primary_exp => this"
        return ECMA262::This.new(context)
      end
      # (exp)
      if lex.eql_lit?(ECMA262::PUNC_LPARENTHESIS)
        if a=exp(context, {}) and lex.eql_lit?(ECMA262::PUNC_RPARENTHESIS)
          @logger.debug "*** primary_exp => ()"
          return ECMA262::ExpParen.new(a)
        else
          raise ParseError.new("no `)' at end of expression", lex)
        end
      end

      t = identifier(context) ||
          literal(context) ||
          array_literal(context) ||
          object_literal(context)

      @logger.debug {
        "*** primary_exp => #{t ? t.to_js : t}"
      }
      t
    end

    # Tests next literal is Literal or not
    #
    # If literal is Literal,
    # return ECMA262::Base object correspoding to expression and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @param context [Context] Lexical Environment
    # @return [ECMA262::Base] expression
    #
    # @see ECMA262 7.8, 7.8.1, 7.8.2
    def literal(context)
      # Literal ::
      # NullLiteral
      # BooleanLiteral
      # NumericLiteral
      # StringLiteral
      # RegularExpressionLiteral
      a = lex.peek_lit(:regexp)
      if a.kind_of? ECMA262::ECMA262Numeric or a.kind_of? ECMA262::ECMA262String or a.kind_of? ECMA262::ECMA262RegExp
        lex.fwd_after_peek
        a
      elsif a.eql? ECMA262::ID_NULL
        lex.fwd_after_peek
        ECMA262::Null.get
      elsif a.eql? ECMA262::ID_TRUE
        lex.fwd_after_peek
        ECMA262::Boolean.get(:true)
      elsif a.eql? ECMA262::ID_FALSE
        lex.fwd_after_peek
        ECMA262::Boolean.get(:false)
      else
        nil
      end
    end

    # Tests next literal is Identifier or not.
    #
    # If literal is Identifier
    # return ECMA262::Lit object and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @param context [Context] Lexical Environment
    #
    # @return [ECMA262::Literal] expression
    #
    # @see ECMA262 11.1.2
    def identifier(context)
      a = lex.peek_lit(:regexp)
      if a.kind_of? ECMA262::IdentifierName and !a.reserved?
        lex.fwd_after_peek
        a.context = context
        a
      else
        nil
      end
    end
    # Tests next literal is ArrayLiteral or not.
    #
    # If literal is ArrayLiteral
    # return ECMA262::ECMA262Array object and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @param context [Context] Lexical Environment
    #
    # @return [ECMA262::ECMA262Array] expression
    #
    # @see ECMA262 11.1.4
    def array_literal(context)
      return nil unless lex.eql_lit?(ECMA262::PUNC_LSQBRAC)
      t = []
      while true
        if lex.eql_lit?(ECMA262::PUNC_COMMA)
          t.push(nil)
        elsif lex.eql_lit?(ECMA262::PUNC_RSQBRAC)
          break
        elsif a = assignment_exp(context, {})
          t.push(a)
          lex.eql_lit?(ECMA262::PUNC_COMMA)
        else
          raise ParseError.new("no `]' end of array", lex)
        end
      end
      ECMA262::ECMA262Array.new(t)
    end
    # Tests next literal is ObjectLiteral or not.
    #
    # If literal is ObjectLiteral
    # return ECMA262::ECMA262Object object and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @param context [Context] Lexical Environment
    #
    # @return [ECMA262::ECMA262Object] expression
    #
    # @see ECMA262 11.1.5
    def object_literal(context)
      #
      # 11.1.5
      #
      # ObjectLiteral :
      # { }
      # { PropertyNameAndValueList }
      # { PropertyNameAndValueList , }
      #
      return nil unless lex.eql_lit?(ECMA262::PUNC_LCURLYBRAC)
      #{}
      if lex.eql_lit?(ECMA262::PUNC_RCURLYBRAC)
        ECMA262::ECMA262Object.new([])
      else
        ECMA262::ECMA262Object.new(property_name_and_value_list(context))
      end
    end

    # Tests next literal is PropertyNameAndValueList or not.
    #
    # If literal is PropertyNameAndValueList
    # return Array object and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @param context [Context] Lexical Environment
    #
    # @return [Array<Array>] expression
    #
    # @see ECMA262 11.1.5
    #
    def property_name_and_value_list(context)
      # PropertyNameAndValueList :
      # PropertyAssignment
      # PropertyNameAndValueList , PropertyAssignment
      #
      # PropertyAssignment :
      # PropertyName : AssignmentExpression
      # get PropertyName ( ) { FunctionBody }
      # set PropertyName ( PropertySetParameterList ) { FunctionBody }
      h = []
      while !lex.eof?
        #get
        if lex.match_lit? ECMA262::ID_GET
          # {get : val}
          if lex.eql_lit? ECMA262::PUNC_COLON
            b = assignment_exp(context, {})
            h.push([ECMA262::ID_GET, b])
          # {get name(){}}
          else
            new_context = ECMA262::Context.new
            new_context.lex_env = context.lex_env.new_declarative_env()
            new_context.var_env = context.var_env.new_declarative_env()
            if(a = property_name(context) and
               lex.eql_lit? ECMA262::PUNC_LPARENTHESIS and
               lex.eql_lit? ECMA262::PUNC_RPARENTHESIS and
               lex.eql_lit? ECMA262::PUNC_LCURLYBRAC and
               b = func_body(new_context) and
               lex.eql_lit? ECMA262::PUNC_RCURLYBRAC)
              h.push([a, ECMA262::StFunc.new(new_context, ECMA262::ID_GET, [], b, :getter => true)])
            else
              raise ParseError.new("unexpceted token", lex)
            end
          end
        #set
        elsif lex.match_lit?(ECMA262::ID_SET)
          # {set : val}
          if lex.eql_lit? ECMA262::PUNC_COLON
            b = assignment_exp(context, {})
            h.push([ECMA262::ID_SET, b])
          # {set name(arg){}}
          else
            new_context = ECMA262::Context.new
            new_context.lex_env = context.lex_env.new_declarative_env()
            new_context.var_env = context.var_env.new_declarative_env()
            if(a = property_name(context) and
               lex.eql_lit? ECMA262::PUNC_LPARENTHESIS and
               arg = property_set_parameter_list(new_context) and
               lex.eql_lit? ECMA262::PUNC_RPARENTHESIS and
               lex.eql_lit? ECMA262::PUNC_LCURLYBRAC and
               b = func_body(new_context) and
               lex.eql_lit? ECMA262::PUNC_RCURLYBRAC)
              h.push([a, ECMA262::StFunc.new(new_context, ECMA262::ID_SET, arg, b, :setter => true)])
            else
              raise ParseError.new("unexpceted token", lex)
            end
          end
        #property
        elsif(a = property_name(context) and
              lex.eql_lit? ECMA262::PUNC_COLON and
              b = assignment_exp(context, {}))
          h.push([a, b])
        else
          raise ParseError.new("unexpceted token", lex)
        end

        if lex.eql_lit?(ECMA262::PUNC_COMMA)
          break if lex.eql_lit?(ECMA262::PUNC_RCURLYBRAC)
        elsif lex.eql_lit?(ECMA262::PUNC_RCURLYBRAC)
          break
        else
          raise ParseError.new("no `}' end of object", lex)
        end
      end
      h
    end

    # Tests next literal is PropertyName or not.
    #
    # If literal is PropertyName
    # return ECMA262::Base object and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @param context [Context] Lexical Environment
    #
    # @return [ECMA262::Base] expression
    #
    # @see ECMA262 11.1.5
    # 11.1.5
    #
    #
    def property_name(context)
      # PropertyName :
      # IdentifierName
      # StringLiteral
      # NumericLiteral
      a = lex.fwd_lit(nil)
      if a.kind_of?(ECMA262::ECMA262String)
        a
      elsif a.kind_of?(ECMA262::IdentifierName)
        ECMA262::ECMA262String.new(a.to_js)
      elsif a.kind_of?(ECMA262::ECMA262Numeric)
        a
      elsif a.eql?(ECMA262::PUNC_COLON)
        nil
      else
        raise ParseError.new("unexpceted token", lex)
      end
    end

    # Tests next literal is PropertySetParameterList or not.
    #
    # If literal is PropertySetParameterList
    # return them and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @param context [Context] Lexical Environment
    #
    # @return [Array<ECMA262::Base>] arguments
    #
    # @see ECMA262 11.1.5
    def property_set_parameter_list(context)
      # PropertySetParameterList :
      # Identifier
      argName = identifier(context)
      context.var_env.record.create_mutable_binding(argName, nil)
      context.var_env.record.set_mutable_binding(argName, :undefined, nil, {:_parameter_list => true})
      context.lex_env.record.create_mutable_binding(argName, nil)
      context.lex_env.record.set_mutable_binding(argName, :undefined, nil, {:_parameter_list => true})
      [argName]
    end

    # Tests next literal is LeftHandSideExpression or not.
    #
    # If literal is LeftHandSideExpression,
    # return ECMA262::Base object correspoding to expression and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @param context [Context] Lexical Environment
    # @return [ECMA262::Base] expression
    #
    # @see ECMA262 11.2
    def left_hand_side_exp(context)
      #
      # LeftHandSideExpression :
      # NewExpression
      # CallExpression
      #
      @logger.debug "*** left_hand_side_exp"

      t = call_exp(context) || new_exp(context)
      #t = new_exp(context) || call_exp(context)

      @logger.debug{
        "*** left_hand_side_exp => #{t ? t.to_js: t}"
      }
      t
    end

    # Tests next literal is NewExpression or not.
    #
    # If literal is NewExpression,
    # return ECMA262::Base object correspoding to expression and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # The NewExpression only matchs no-arguments-constructor because
    # member expression also has "new MemberExpression Arguments"
    #
    # For example,
    #
    # 1. new A;
    # 2. new A[B];
    # 3. new A.B;
    # 4. new A.B();
    # 5. new new B();
    # 6. A();
    #
    # 1 to 3 are NewExpression.
    # 4 is MemberExpression.
    # 5 's first new is NewExpression and second one is MemberExpression.
    # 6 is CallExpression
    #
    # In the results, NewExpression can be rewritten as follows:
    #
    #      NewExpression :
    #      MemberExpression [lookahead ∉ {(}]
    #      new NewExpression [lookahead ∉ {(}]
    #
    # @param context [Context] Lexical Environment
    # @option options :no_in [Boolean] If set, the parser interpret as RelationExpressionNoIn
    #
    # @return [ECMA262::Base] expression
    #
    # @see ECMA262 11.2
    # @see #call_exp
    def new_exp(context)
      # NewExpression :
      # MemberExpression
      # new NewExpression
      if lex.eql_lit?(ECMA262::ID_NEW)
        if a = new_exp(context)
          if lex.eql_lit? ECMA262::PUNC_LPARENTHESIS
            # minjs evaluate CallExpression first, so
            # program never falls to here.
            raise ParseError.new("unexpceted token", lex)
            nil # this is not NewExpression, may be MemberExpression.
          end
          #puts "new_exp> #{a.to_js}"
          ECMA262::ExpNew.new(a, nil)
        else
          # minjs evaluate CallExpression first, so
          # raise exception when program falls to here.
          raise ParseError.new("unexpceted token", lex)
          #nil
        end
      else
        member_exp(context)
      end
    end
    # Tests next literal is CallExpression or not.
    #
    # If literal is CallExpression,
    # return ECMA262::Base object correspoding to expression and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @see ECMA262 11.2
    # @see #new_exp
    def call_exp(context)
      # CallExpression :
      # MemberExpression Arguments
      # CallExpression Arguments
      # CallExpression [ Expression ]
      # CallExpression . IdentifierName
      if a = member_exp(context)
        if b = arguments(context)
          t = ECMA262::ExpCall.new(a, b)
        # if b is nil, this may be MemberExpression of NewExpression
        else
          return a
        end
      else
        return nil
      end

      while true
        if b = arguments(context)
          t = ECMA262::ExpCall.new(t, b)
        elsif lex.eql_lit?(ECMA262::PUNC_LSQBRAC)
          if b=exp(context, {}) and lex.eql_lit?(ECMA262::PUNC_RSQBRAC)
            t = ECMA262::ExpPropBrac.new(t, b)
          else
            raise ParseError.new("unexpceted token", lex)
          end
        elsif lex.eql_lit?(ECMA262::PUNC_PERIOD)
          if (b=lex.fwd_lit(nil)).kind_of?(ECMA262::IdentifierName)
            t = ECMA262::ExpProp.new(t, b)
          else
            raise ParseError.new("unexpceted token", lex)
          end
        else
          break
        end
      end
      t
    end

    # Tests next literal is MemberExpression or not.
    #
    # If literal is MemberExpression,
    # return ECMA262::Base object correspoding to expression and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @param context [Context] Lexical Environment
    # @option options :no_in [Boolean] If set, the parser interpret as RelationExpressionNoIn
    #
    # @return [ECMA262::Base] expression
    #
    # @see ECMA262 11.2
    #
    def member_exp(context)
      # MemberExpression :
      # PrimaryExpression
      # FunctionExpression
      # MemberExpression [ Expression ]
      # MemberExpression . IdentifierName
      # new MemberExpression Arguments
      #
      t = lex.eval_lit{
        if lex.eql_lit? ECMA262::ID_NEW
           if a = member_exp(context)
             b = arguments(context)
             # if b is nil, this may be NewExpression
             if b
               s = b.collect{|x| x.to_js}.join(',');
               #puts "member_exp> [new] #{a.to_js} (#{s})"
               next ECMA262::ExpNew.new(a, b)
             else
               return nil
             end
           else
             return nil
           end
        end
      } || primary_exp(context) || func_exp(context)
      return nil if t.nil?

      while true
        if lex.eql_lit?(ECMA262::PUNC_LSQBRAC)
          if b=exp(context, {}) and lex.eql_lit?(ECMA262::PUNC_RSQBRAC)
            t = ECMA262::ExpPropBrac.new(t, b)
          else
            raise ParseError.new("unexpceted token", lex)
          end
        elsif lex.eql_lit?(ECMA262::PUNC_PERIOD)
          if (b=lex.fwd_lit(nil)).kind_of?(ECMA262::IdentifierName)
            t = ECMA262::ExpProp.new(t, b)
          else
            raise ParseError.new("unexpceted token", lex)
          end
        else
          break
        end
      end
      t
    end
    # Tests next literal is Arguments or not.
    #
    # If literal is Arguments
    # return them and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @param context [Context] Lexical Environment
    #
    # @return [Array<ECMA262::Base>] arguments
    #
    # @see ECMA262 11.2
    def arguments(context)
      # Arguments :
      # ( )
      # ( ArgumentList )
      return nil if lex.eql_lit?(ECMA262::PUNC_LPARENTHESIS).nil?
      return [] if lex.eql_lit?(ECMA262::PUNC_RPARENTHESIS)

      args = []
      while true
        if t = assignment_exp(context, {})
          args.push(t)
        else
          raise ParseError.new("unexpected token", lex)
        end
        if lex.eql_lit?(ECMA262::PUNC_COMMA)
          ;
        elsif lex.eql_lit?(ECMA262::PUNC_RPARENTHESIS)
          break
        else
          raise ParseError.new("unexpected token", lex)
        end
      end
      args
    end

    # Tests next literal is PostfixExpression or not.
    #
    # If literal is PostfixExpression
    # return ECMA262::Base object and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @param context [Context] Lexical Environment
    #
    # @return [ECMA262::ECMA262Object] expression
    #
    # @see ECMA262 11.3
    def postfix_exp(context)
      exp = left_hand_side_exp(context)
      return nil if exp.nil?
      if punc = (lex.eql_lit_nolt?(ECMA262::PUNC_INC) ||
                 lex.eql_lit_nolt?(ECMA262::PUNC_DEC))
        if punc == ECMA262::PUNC_INC
          ECMA262::ExpPostInc.new(exp)
        else
          ECMA262::ExpPostDec.new(exp)
        end
      else
        exp
      end
    end

    # Tests next literal is UnaryExpression or not.
    #
    # If literal is UnaryExpression,
    # return ECMA262::Base object correspoding to expression and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @param context [Context] Lexical Environment
    # @option options :no_in [Boolean] If set, the parser interpret as RelationExpressionNoIn
    # @return [ECMA262::Base] expression
    #
    # see ECMA262 11.4
    def unary_exp(context)
      if punc = (lex.eql_lit?(ECMA262::ID_DELETE) ||
                 lex.eql_lit?(ECMA262::ID_VOID) ||
                 lex.eql_lit?(ECMA262::ID_TYPEOF) ||
                 lex.eql_lit?(ECMA262::PUNC_INC) ||
                 lex.eql_lit?(ECMA262::PUNC_DEC) ||
                 lex.eql_lit?(ECMA262::PUNC_ADD) ||
                 lex.eql_lit?(ECMA262::PUNC_SUB) ||
                 lex.eql_lit?(ECMA262::PUNC_NOT) ||
                 lex.eql_lit?(ECMA262::PUNC_LNOT))
        exp = unary_exp(context)
        if exp.nil?
          raise ParseError.new("unexpceted token", lex)
        elsif punc == ECMA262::PUNC_INC
          ECMA262::ExpPreInc.new(exp)
        elsif punc == ECMA262::PUNC_DEC
          ECMA262::ExpPreDec.new(exp)
        elsif punc == ECMA262::PUNC_ADD
          ECMA262::ExpPositive.new(exp)
        elsif punc == ECMA262::PUNC_SUB
          ECMA262::ExpNegative.new(exp)
        elsif punc == ECMA262::PUNC_NOT
          ECMA262::ExpBitwiseNot.new(exp)
        elsif punc == ECMA262::PUNC_LNOT
          ECMA262::ExpLogicalNot.new(exp)
        elsif punc.respond_to?(:val)
            if punc.val == :delete
              ECMA262::ExpDelete.new(exp)
            elsif punc.val == :void
              ECMA262::ExpVoid.new(exp)
            elsif punc.val == :typeof
              ECMA262::ExpTypeof.new(exp)
            end
        end
      else
        postfix_exp(context)
      end
    end

    # Tests next literal is MultiplicativeExpression or not.
    #
    # If literal is MultiplicativeExpression,
    # return ECMA262::Base object correspoding to expression and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @param context [Context] Lexical Environment
    # @option options :no_in [Boolean] If set, the parser interpret as RelationExpressionNoIn
    #
    # @return [ECMA262::Base] expression
    #
    # @see ECMA262 11.5
    def multiplicative_exp(context)
      a = unary_exp(context)
      return nil if !a
      t = a
      while punc = lex.eql_lit?(ECMA262::PUNC_MUL) ||
                   lex.eql_lit?(ECMA262::PUNC_DIV, :div) ||
                   lex.eql_lit?(ECMA262::PUNC_MOD)

        if b = unary_exp(context)
          if punc == ECMA262::PUNC_MUL
            t = ECMA262::ExpMul.new(t, b)
          elsif punc == ECMA262::PUNC_DIV
            t = ECMA262::ExpDiv.new(t, b)
          else
            t = ECMA262::ExpMod.new(t, b)
          end
        else
          raise ParseError.new("unexpceted token", lex)
        end
      end
      t
    end

    # Tests next literal is AdditiveExpression or not.
    #
    # If literal is AdditiveExpression,
    # return ECMA262::Base object correspoding to expression and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @param context [Context] Lexical Environment
    #
    # @return [ECMA262::Base] expression
    #
    # @see ECMA262 11.6
    def additive_exp(context)
      # AdditiveExpression :
      #   MultiplicativeExpression AdditiveExpression +
      #   MultiplicativeExpression AdditiveExpression -
      #   MultiplicativeExpression
      a = multiplicative_exp(context)
      return nil if !a

      t = a
      while punc = lex.eql_lit?(ECMA262::PUNC_ADD) || lex.eql_lit?(ECMA262::PUNC_SUB)
        if b = multiplicative_exp(context)
          if punc == ECMA262::PUNC_ADD
            t = ECMA262::ExpAdd.new(t, b)
          else
            t = ECMA262::ExpSub.new(t, b)
          end
        else
          raise ParseError.new("unexpceted token", lex)
        end
      end
      t
    end
    # Tests next literal is ShiftExpression or not.
    #
    # If literal is ShiftExpression,
    # return ECMA262::Base object correspoding to expression and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @param context [Context] Lexical Environment
    # @option options :no_in [Boolean] If set, the parser interpret as RelationExpressionNoIn
    # @return [ECMA262::Base] expression
    #
    # see ECMA262 11.8
    def shift_exp(context)
      a = additive_exp(context)
      return nil if !a

      t = a
      while punc = lex.eql_lit?(ECMA262::PUNC_LSHIFT) ||
                   lex.eql_lit?(ECMA262::PUNC_RSHIFT) ||
                   lex.eql_lit?(ECMA262::PUNC_URSHIFT)
        if b = additive_exp(context)
          if punc == ECMA262::PUNC_LSHIFT
            t = ECMA262::ExpLShift.new(t, b)
          elsif punc == ECMA262::PUNC_RSHIFT
            t = ECMA262::ExpRShift.new(t, b)
          elsif punc == ECMA262::PUNC_URSHIFT
            t = ECMA262::ExpURShift.new(t, b)
          end
        else
          raise ParseError.new("unexpceted token", lex)
        end
      end
      t
    end
    # Tests next literal is RelationalExpression or not.
    #
    # If literal is RelationalExpression,
    # return ECMA262::Base object correspoding to expression and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @param context [Context] Lexical Environment
    # @option options :no_in [Boolean] If set, the parser interpret as RelationExpressionNoIn
    # @return [ECMA262::Base] expression
    #
    # see ECMA262 11.8
    def relational_exp(context, options)
      #RelationalExpression :
      # ShiftExpression
      # RelationalExpression < ShiftExpression
      # RelationalExpression > ShiftExpression
      # RelationalExpression <= ShiftExpression
      # RelationalExpression >= ShiftExpression
      # RelationalExpression instanceof ShiftExpression
      # RelationalExpression in ShiftExpression
      a = shift_exp(context)
      return nil if !a

      t = a
      while (punc = lex.eql_lit?(ECMA262::PUNC_LT) || lex.eql_lit?(ECMA262::PUNC_GT) ||
                    lex.eql_lit?(ECMA262::PUNC_LTEQ) || lex.eql_lit?(ECMA262::PUNC_GTEQ) ||
                    lex.eql_lit?(ECMA262::ID_INSTANCEOF) || (!options[:no_in] && lex.eql_lit?(ECMA262::ID_IN)))
        if b = shift_exp(context)
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
          raise ParseError.new("unexpceted token", lex)
        end
      end
      t
    end
    # Tests next literal is EqualityExpression or not.
    #
    # If literal is EqualityExpression,
    # return ECMA262::Base object correspoding to expression and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @param context [Context] Lexical Environment
    # @option options :no_in [Boolean] If set, the parser interpret as RelationExpressionNoIn
    #
    # @return [ECMA262::Base] expression
    #
    # @see ECMA262 11.9
    def equality_exp(context, options)
      a = relational_exp(context, options)
      return nil if !a

      t = a
      while punc = lex.eql_lit?(ECMA262::PUNC_EQ) ||
                   lex.eql_lit?(ECMA262::PUNC_NEQ) ||
                   lex.eql_lit?(ECMA262::PUNC_SEQ) ||
                   lex.eql_lit?(ECMA262::PUNC_SNEQ)
        if b = relational_exp(context, options)
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
          raise ParseError.new("unexpceted token", lex)
        end
      end
      t
    end

    # Tests next literal is BitwiseAndExpression or not.
    #
    # If literal is BitwiseAndExpression,
    # return ECMA262::Base object correspoding to expression and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @param context [Context] Lexical Environment
    # @option options :no_in [Boolean] If set, the parser interpret as RelationExpressionNoIn
    #
    # @return [ECMA262::Base] expression
    #
    # @see ECMA262 11.10
    def bitwise_and_exp(context, options)
      a = equality_exp(context, options)
      return nil if !a

      t = a
      while punc = lex.eql_lit?(ECMA262::PUNC_AND)
        if b = equality_exp(context, options)
          t = ECMA262::ExpAnd.new(t, b)
        else
          raise ParseError.new("unexpceted token", lex)
        end
      end
      t
    end

    # Tests next literal is BitwiseXorExpression or not.
    #
    # If literal is BitwiseXorExpression,
    # return ECMA262::Base object correspoding to expression and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @param context [Context] Lexical Environment
    # @option options :no_in [Boolean] If set, the parser interpret as RelationExpressionNoIn
    #
    # @return [ECMA262::Base] expression
    #
    # @see ECMA262 11.10
    def bitwise_xor_exp(context, options)
      a = bitwise_and_exp(context, options)
      return nil if !a

      t = a
      while punc = lex.eql_lit?(ECMA262::PUNC_XOR)
        if b = bitwise_and_exp(context, options)
          t = ECMA262::ExpXor.new(t, b)
        else
          raise ParseError.new("unexpceted token", lex)
        end
      end

      t
    end

    # Tests next literal is BitwiseOrExpression or not.
    #
    # If literal is BitwiseOrExpression,
    # return ECMA262::Base object correspoding to expression and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @param context [Context] Lexical Environment
    # @option options :no_in [Boolean] If set, the parser interpret as RelationExpressionNoIn
    #
    # @return [ECMA262::Base] expression
    #
    # @see ECMA262 11.10
    def bitwise_or_exp(context, options)
      a = bitwise_xor_exp(context, options)
      return nil if !a

      t = a
      while punc = lex.eql_lit?(ECMA262::PUNC_OR)
        if b = bitwise_xor_exp(context, options)
          t = ECMA262::ExpOr.new(t, b)
        else
          raise ParseError.new("unexpceted token", lex)
        end
      end
      t
    end

    # Tests next literal is LogicalAndExpression or not
    #
    # If literal is LogicalAndExpression,
    # return ECMA262::Base object correspoding to expression and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @param context [Context] Lexical Environment
    # @return [ECMA262::Base] expression
    # @option options :no_in [Boolean] If set, the parser interpret as RelationExpressionNoIn
    #
    # @see ECMA262 11.11
    def logical_and_exp(context, options)
      a = bitwise_or_exp(context, options)
      return nil if !a

      t = a
      while punc = lex.eql_lit?(ECMA262::PUNC_LAND)
        if b = bitwise_or_exp(context, options)
          t = ECMA262::ExpLogicalAnd.new(t, b)
        else
          raise ParseError.new("unexpceted token", lex)
        end
      end

      t
    end

    # Tests next literal is LogicalOrExpression or not
    #
    # If literal is LogicalOrExpression,
    # return ECMA262::Base object correspoding to expression and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @param context [Context] Lexical Environment
    # @return [ECMA262::Base] expression
    # @option options :no_in [Boolean] If set, the parser interpret as RelationExpressionNoIn
    #
    # @see ECMA262 11.12
    def logical_or_exp(context, options)
      a = logical_and_exp(context, options)
      return nil if !a

      t = a
      while punc = lex.eql_lit?(ECMA262::PUNC_LOR)
        if b = logical_and_exp(context, options)
          t = ECMA262::ExpLogicalOr.new(t, b)
        else
          raise ParseError.new("unexpceted token", lex)
        end
      end

      t
    end
    # Tests next literal is ConditionalExpression or not.
    #
    # If literal is ConditionalExpression,
    # return ECMA262::Base object correspoding to expression and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @param context [Context] Lexical Environment
    #
    # @return [ECMA262::Base] expression
    #
    # @see ECMA262 11.12
    def cond_exp(context, options)
      a = logical_or_exp(context, options)
      return nil if !a

      if lex.eql_lit?(ECMA262::PUNC_CONDIF)
        if b=assignment_exp(context, options) and lex.eql_lit?(ECMA262::PUNC_COLON) and c=assignment_exp(context, options)
          ECMA262::ExpCond.new(a, b, c)
        else
          raise ParseError.new("unexpceted token", lex)
        end
      else
        a
      end
    end
    # Tests next literal is AssignmentExpression or not.
    #
    # If literal is AssignmentExpression,
    # return ECMA262::Base object correspoding to expression and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @param context [Context] Lexical Environment
    # @option options :no_in [Boolean] If set, the parser interpret as RelationExpressionNoIn
    #
    # @see ECMA262 11.13
    def assignment_exp(context, options)
      # AssignmentExpression :
      #  ConditionalExpression
      #  LeftHandSideExpression = AssignmentExpression
      #  LeftHandSideExpression AssignmentOperator AssignmentExpression
      @logger.debug "*** assignment_exp"

      t = cond_exp(context, options)
      return nil if t.nil?

      if !t.left_hand_side_exp?
        return  t
      end
      left_hand = t
      punc = lex.peek_lit(:div)
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
        lex.fwd_after_peek
        if b = assignment_exp(context, options)
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
        else
          raise ParseError.new("unexpceted token", lex)
        end
      else
        @logger.debug {
          "*** assignment_exp => #{t ? t.to_js : t}"
        }
        t
      end
    end

    # Tests next literal is Expression or not.
    #
    # If literal is Expression,
    # return ECMA262::Base object correspoding to expression and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @param context [Context] Lexical Environment
    # @option options :no_in [Boolean] If set, the parser interpret as RelationExpressionNoIn
    #
    # @return [ECMA262::Base] expression
    #
    # @see ECMA262 11.14
    def exp(context, options)
      # Expression :
      # AssignmentExpression
      # Expression , AssignmentExpression
      @logger.debug "*** expression"

      t = assignment_exp(context, options)
      return nil if t.nil?
      while punc = lex.eql_lit?(ECMA262::PUNC_COMMA)
        if b = assignment_exp(context, options)
          t = ECMA262::ExpComma.new(t, b)
        else
          raise ParseError.new("unexpceted token", lex)
        end
      end
      @logger.debug{
        "*** expression => #{t ? t.to_js : t}"
      }
      t
    end
  end
end

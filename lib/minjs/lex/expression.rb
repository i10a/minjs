# coding: utf-8
module Minjs::Lex
  # Expression
  module Expression
    include Minjs
    # Tests next literal is PrimaryExpression or not.
    #
    # If literal is PrimaryExpression
    # return ECMA262::Base object and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @param var_env [EnvRecord] Lexical Environment
    #
    # @return [ECMA262::ECMA262Object] expression
    #
    # @see ECMA262 11.1
    def primary_exp(var_env)
      @logger.debug "*** primary_exp"

      if eql_lit?(ECMA262::ID_THIS)
        @logger.debug "*** primary_exp => this"
        return ECMA262::This.new
      end
      # (exp)
      if eql_lit?(ECMA262::PUNC_LPARENTHESIS)
        if a=exp(var_env, {}) and eql_lit?(ECMA262::PUNC_RPARENTHESIS)
          @logger.debug "*** primary_exp => ()"
          return ECMA262::ExpParen.new(a)
        else
          raise ParseError.new("no `)' at end of expression", self)
        end
      end

      t = literal(var_env) ||
          identifier(var_env) ||
          array_literal(var_env) ||
          object_literal(var_env)

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
    # @param var_env [EnvRecord] Lexical Environment
    # @return [ECMA262::Base] expression
    #
    # @see ECMA262 7.8, 7.8.1, 7.8.2
    def literal(var_env)
      # Literal ::
      # NullLiteral
      # BooleanLiteral
      # NumericLiteral
      # StringLiteral
      # RegularExpressionLiteral
      a = peek_lit(:regexp)
      if a.kind_of? ECMA262::ECMA262Numeric or a.kind_of? ECMA262::ECMA262String or a.kind_of? ECMA262::ECMA262RegExp
        fwd_after_peek
        a
      elsif a .eql? ECMA262::ID_NULL
        fwd_after_peek
        ECMA262::Null.get
      elsif a .eql? ECMA262::ID_TRUE
        fwd_after_peek
        ECMA262::Boolean.get(:true)
      elsif a .eql? ECMA262::ID_FALSE
        fwd_after_peek
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
    # @param var_env [EnvRecord] Lexical Environment
    #
    # @return [ECMA262::Literal] expression
    #
    # @see ECMA262 11.1.2
    def identifier(var_env)
      a = peek_lit(:regexp)
      if a.kind_of? ECMA262::IdentifierName and !a.reserved?
        fwd_after_peek
        #a.var_env = var_env
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
    # @param var_env [EnvRecord] Lexical Environment
    #
    # @return [ECMA262::ECMA262Array] expression
    #
    # @see ECMA262 11.1.4
    def array_literal(var_env)
      return nil unless eql_lit?(ECMA262::PUNC_LSQBRAC)
      t = []
      while true
        if eql_lit?(ECMA262::PUNC_COMMA)
          t.push(nil)
        elsif eql_lit?(ECMA262::PUNC_RSQBRAC)
          break
        elsif a = assignment_exp(var_env, {})
          t.push(a)
          eql_lit?(ECMA262::PUNC_COMMA)
        else
          raise ParseError.new("no `]' end of array", self)
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
    # @param var_env [EnvRecord] Lexical Environment
    #
    # @return [ECMA262::ECMA262Object] expression
    #
    # @see ECMA262 11.1.5
    def object_literal(var_env)
      #
      # 11.1.5
      #
      # ObjectLiteral :
      # { }
      # { PropertyNameAndValueList }
      # { PropertyNameAndValueList , }
      #
      return nil unless eql_lit?(ECMA262::PUNC_LCURLYBRAC)
      #{}
      if eql_lit?(ECMA262::PUNC_RCURLYBRAC)
        ECMA262::ECMA262Object.new([])
      else
        ECMA262::ECMA262Object.new(property_name_and_value_list(var_env))
      end
    end

    # Tests next literal is PropertyNameAndValueList or not.
    #
    # If literal is PropertyNameAndValueList
    # return Array object and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @param var_env [EnvRecord] Lexical Environment
    #
    # @return [Array<Array>] expression
    #
    # @see ECMA262 11.1.5
    #
    def property_name_and_value_list(var_env)
      # PropertyNameAndValueList :
      # PropertyAssignment
      # PropertyNameAndValueList , PropertyAssignment
      #
      # PropertyAssignment :
      # PropertyName : AssignmentExpression
      # get PropertyName ( ) { FunctionBody }
      # set PropertyName ( PropertySetParameterList ) { FunctionBody }
      h = []
      while !eof?
        #get
        if match_lit? ECMA262::ID_GET
          # {get : val}
          if eql_lit? ECMA262::PUNC_COLON
            b = assignment_exp(var_env, {})
            h.push([ECMA262::ID_GET, b])
          # {get name(){}}
          else
            new_var_env = ECMA262::LexEnv.new(outer: var_env)
            if(a = property_name(var_env) and
               eql_lit? ECMA262::PUNC_LPARENTHESIS and
               eql_lit? ECMA262::PUNC_RPARENTHESIS and
               eql_lit? ECMA262::PUNC_LCURLYBRAC and
               b = func_body(new_var_env) and
               eql_lit? ECMA262::PUNC_RCURLYBRAC)
              h.push([a, f = ECMA262::StFunc.new(new_var_env, ECMA262::ID_GET, [], b, :getter => true)])
              #new_var_env.func = f
            else
              raise ParseError.new("unexpceted token", self)
            end
          end
        #set
        elsif match_lit?(ECMA262::ID_SET)
          # {set : val}
          if eql_lit? ECMA262::PUNC_COLON
            b = assignment_exp(var_env, {})
            h.push([ECMA262::ID_SET, b])
          # {set name(arg){}}
          else
            new_var_env = ECMA262::LexEnv.new(outer: var_env)
            if(a = property_name(var_env) and
               eql_lit? ECMA262::PUNC_LPARENTHESIS and
               arg = property_set_parameter_list(new_var_env) and
               eql_lit? ECMA262::PUNC_RPARENTHESIS and
               eql_lit? ECMA262::PUNC_LCURLYBRAC and
               b = func_body(new_var_env) and
               eql_lit? ECMA262::PUNC_RCURLYBRAC)
              h.push([a, f = ECMA262::StFunc.new(new_var_env, ECMA262::ID_SET, arg, b, :setter => true)])
              #new_var_env.func = f
            else
              raise ParseError.new("unexpceted token", self)
            end
          end
        #property
        elsif(a = property_name(var_env) and
              eql_lit? ECMA262::PUNC_COLON and
              b = assignment_exp(var_env, {}))
          h.push([a, b])
        else
          raise ParseError.new("unexpceted token", self)
        end

        if eql_lit?(ECMA262::PUNC_COMMA)
          break if eql_lit?(ECMA262::PUNC_RCURLYBRAC)
        elsif eql_lit?(ECMA262::PUNC_RCURLYBRAC)
          break
        else
          raise ParseError.new("no `}' end of object", self)
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
    # @param var_env [EnvRecord] Lexical Environment
    #
    # @return [ECMA262::Base] expression
    #
    # @see ECMA262 11.1.5
    # 11.1.5
    #
    #
    def property_name(var_env)
      # PropertyName :
      # IdentifierName
      # StringLiteral
      # NumericLiteral
      a = fwd_lit(nil)
      if a.kind_of?(ECMA262::ECMA262String)
        a
      elsif a.kind_of?(ECMA262::IdentifierName)
        ECMA262::ECMA262String.new(a.to_js)
      elsif a.kind_of?(ECMA262::ECMA262Numeric)
        a
      elsif a.eql?(ECMA262::PUNC_COLON)
        nil
      else
        raise ParseError.new("unexpceted token", self)
      end
    end

    # Tests next literal is PropertySetParameterList or not.
    #
    # If literal is PropertySetParameterList
    # return them and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @param var_env [EnvRecord] Lexical Environment
    #
    # @return [Array<ECMA262::Base>] arguments
    #
    # @see ECMA262 11.1.5
    def property_set_parameter_list(var_env)
      # PropertySetParameterList :
      # Identifier
      argName = identifier(var_env)

      var_env.record.create_mutable_binding(argName, nil)
      var_env.record.set_mutable_binding(argName, :undefined, nil, _parameter_list: true)
      [argName]
    end

    # Tests next literal is LeftHandSideExpression or not.
    #
    # If literal is LeftHandSideExpression,
    # return ECMA262::Base object correspoding to expression and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @param var_env [EnvRecord] Lexical Environment
    # @return [ECMA262::Base] expression
    #
    # @see ECMA262 11.2
    def left_hand_side_exp(var_env)
      #
      # LeftHandSideExpression :
      # NewExpression
      # CallExpression
      #
      @logger.debug "*** left_hand_side_exp"

      t = call_exp(var_env) || new_exp(var_env)
      #t = new_exp(var_env) || call_exp(var_env)

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
    # @param var_env [EnvRecord] Lexical Environment
    # @option options :no_in [Boolean] If set, the parser interpret as RelationExpressionNoIn
    #
    # @return [ECMA262::Base] expression
    #
    # @see ECMA262 11.2
    # @see #call_exp
    def new_exp(var_env)
      # NewExpression :
      # MemberExpression
      # new NewExpression
      if eql_lit?(ECMA262::ID_NEW)
        if a = new_exp(var_env)
          if eql_lit? ECMA262::PUNC_LPARENTHESIS
            # minjs evaluate CallExpression first, so
            # program never falls to here.
            raise ParseError.new("unexpceted token", self)
            nil # this is not NewExpression, may be MemberExpression.
          end
          #puts "new_exp> #{a.to_js}"
          ECMA262::ExpNew.new(a, nil)
        else
          # minjs evaluate CallExpression first, so
          # raise exception when program falls to here.
          raise ParseError.new("unexpceted token", self)
          #nil
        end
      else
        member_exp(var_env)
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
    def call_exp(var_env)
      # CallExpression :
      # MemberExpression Arguments
      # CallExpression Arguments
      # CallExpression [ Expression ]
      # CallExpression . IdentifierName
      if a = member_exp(var_env)
        if b = arguments(var_env)
          t = ECMA262::ExpCall.new(a, b)
        # if b is nil, this may be MemberExpression of NewExpression
        else
          return a
        end
      else
        return nil
      end

      while true
        if b = arguments(var_env)
          t = ECMA262::ExpCall.new(t, b)
        elsif eql_lit?(ECMA262::PUNC_LSQBRAC)
          if b=exp(var_env, {}) and eql_lit?(ECMA262::PUNC_RSQBRAC)
            t = ECMA262::ExpPropBrac.new(t, b)
          else
            raise ParseError.new("unexpceted token", self)
          end
        elsif eql_lit?(ECMA262::PUNC_PERIOD)
          if (b=fwd_lit(nil)).kind_of?(ECMA262::IdentifierName)
            t = ECMA262::ExpProp.new(t, b)
          else
            raise ParseError.new("unexpceted token", self)
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
    # @param var_env [EnvRecord] Lexical Environment
    # @option options :no_in [Boolean] If set, the parser interpret as RelationExpressionNoIn
    #
    # @return [ECMA262::Base] expression
    #
    # @see ECMA262 11.2
    #
    def member_exp(var_env)
      # MemberExpression :
      # PrimaryExpression
      # FunctionExpression
      # MemberExpression [ Expression ]
      # MemberExpression . IdentifierName
      # new MemberExpression Arguments
      #
      t = eval_lit{
        if eql_lit? ECMA262::ID_NEW
           if a = member_exp(var_env)
             b = arguments(var_env)
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
      } || primary_exp(var_env) || func_exp(var_env)
      return nil if t.nil?

      while true
        if eql_lit?(ECMA262::PUNC_LSQBRAC)
          if b=exp(var_env, {}) and eql_lit?(ECMA262::PUNC_RSQBRAC)
            t = ECMA262::ExpPropBrac.new(t, b)
          else
            raise ParseError.new("unexpceted token", self)
          end
        elsif eql_lit?(ECMA262::PUNC_PERIOD)
          if (b=fwd_lit(nil)).kind_of?(ECMA262::IdentifierName)
            t = ECMA262::ExpProp.new(t, b)
          else
            raise ParseError.new("unexpceted token", self)
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
    # @param var_env [EnvRecord] Lexical Environment
    #
    # @return [Array<ECMA262::Base>] arguments
    #
    # @see ECMA262 11.2
    def arguments(var_env)
      # Arguments :
      # ( )
      # ( ArgumentList )
      return nil if eql_lit?(ECMA262::PUNC_LPARENTHESIS).nil?
      return [] if eql_lit?(ECMA262::PUNC_RPARENTHESIS)

      args = []
      while true
        if t = assignment_exp(var_env, {})
          args.push(t)
        else
          raise ParseError.new("unexpected token", self)
        end
        if eql_lit?(ECMA262::PUNC_COMMA)
          ;
        elsif eql_lit?(ECMA262::PUNC_RPARENTHESIS)
          break
        else
          raise ParseError.new("unexpected token", self)
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
    # @param var_env [EnvRecord] Lexical Environment
    #
    # @return [ECMA262::ECMA262Object] expression
    #
    # @see ECMA262 11.3
    def postfix_exp(var_env)
      exp = left_hand_side_exp(var_env)
      return nil if exp.nil?
      if punc = (eql_lit_nolt?(ECMA262::PUNC_INC) ||
                 eql_lit_nolt?(ECMA262::PUNC_DEC))
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
    # @param var_env [EnvRecord] Lexical Environment
    # @option options :no_in [Boolean] If set, the parser interpret as RelationExpressionNoIn
    # @return [ECMA262::Base] expression
    #
    # see ECMA262 11.4
    def unary_exp(var_env)
      if punc = (eql_lit?(ECMA262::ID_DELETE) ||
                 eql_lit?(ECMA262::ID_VOID) ||
                 eql_lit?(ECMA262::ID_TYPEOF) ||
                 eql_lit?(ECMA262::PUNC_INC) ||
                 eql_lit?(ECMA262::PUNC_DEC) ||
                 eql_lit?(ECMA262::PUNC_ADD) ||
                 eql_lit?(ECMA262::PUNC_SUB) ||
                 eql_lit?(ECMA262::PUNC_NOT) ||
                 eql_lit?(ECMA262::PUNC_LNOT))
        exp = unary_exp(var_env)
        if exp.nil?
          raise ParseError.new("unexpceted token", self)
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
        postfix_exp(var_env)
      end
    end

    # Tests next literal is MultiplicativeExpression or not.
    #
    # If literal is MultiplicativeExpression,
    # return ECMA262::Base object correspoding to expression and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @param var_env [EnvRecord] Lexical Environment
    # @option options :no_in [Boolean] If set, the parser interpret as RelationExpressionNoIn
    #
    # @return [ECMA262::Base] expression
    #
    # @see ECMA262 11.5
    def multiplicative_exp(var_env)
      a = unary_exp(var_env)
      return nil if !a
      t = a
      while punc = eql_lit?(ECMA262::PUNC_MUL) ||
                   eql_lit?(ECMA262::PUNC_DIV, :div) ||
                   eql_lit?(ECMA262::PUNC_MOD)

        if b = unary_exp(var_env)
          if punc == ECMA262::PUNC_MUL
            t = ECMA262::ExpMul.new(t, b)
          elsif punc == ECMA262::PUNC_DIV
            t = ECMA262::ExpDiv.new(t, b)
          else
            t = ECMA262::ExpMod.new(t, b)
          end
        else
          raise ParseError.new("unexpceted token", self)
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
    # @param var_env [EnvRecord] Lexical Environment
    #
    # @return [ECMA262::Base] expression
    #
    # @see ECMA262 11.6
    def additive_exp(var_env)
      # AdditiveExpression :
      #   MultiplicativeExpression AdditiveExpression +
      #   MultiplicativeExpression AdditiveExpression -
      #   MultiplicativeExpression
      a = multiplicative_exp(var_env)
      return nil if !a

      t = a
      while punc = eql_lit?(ECMA262::PUNC_ADD) || eql_lit?(ECMA262::PUNC_SUB)
        if b = multiplicative_exp(var_env)
          if punc == ECMA262::PUNC_ADD
            t = ECMA262::ExpAdd.new(t, b)
          else
            t = ECMA262::ExpSub.new(t, b)
          end
        else
          raise ParseError.new("unexpceted token", self)
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
    # @param var_env [EnvRecord] Lexical Environment
    # @option options :no_in [Boolean] If set, the parser interpret as RelationExpressionNoIn
    # @return [ECMA262::Base] expression
    #
    # see ECMA262 11.8
    def shift_exp(var_env)
      a = additive_exp(var_env)
      return nil if !a

      t = a
      while punc = eql_lit?(ECMA262::PUNC_LSHIFT) ||
                   eql_lit?(ECMA262::PUNC_RSHIFT) ||
                   eql_lit?(ECMA262::PUNC_URSHIFT)
        if b = additive_exp(var_env)
          if punc == ECMA262::PUNC_LSHIFT
            t = ECMA262::ExpLShift.new(t, b)
          elsif punc == ECMA262::PUNC_RSHIFT
            t = ECMA262::ExpRShift.new(t, b)
          elsif punc == ECMA262::PUNC_URSHIFT
            t = ECMA262::ExpURShift.new(t, b)
          end
        else
          raise ParseError.new("unexpceted token", self)
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
    # @param var_env [EnvRecord] Lexical Environment
    # @option options :no_in [Boolean] If set, the parser interpret as RelationExpressionNoIn
    # @return [ECMA262::Base] expression
    #
    # see ECMA262 11.8
    def relational_exp(var_env, options)
      #RelationalExpression :
      # ShiftExpression
      # RelationalExpression < ShiftExpression
      # RelationalExpression > ShiftExpression
      # RelationalExpression <= ShiftExpression
      # RelationalExpression >= ShiftExpression
      # RelationalExpression instanceof ShiftExpression
      # RelationalExpression in ShiftExpression
      a = shift_exp(var_env)
      return nil if !a

      t = a
      while (punc = eql_lit?(ECMA262::PUNC_LT) || eql_lit?(ECMA262::PUNC_GT) ||
                    eql_lit?(ECMA262::PUNC_LTEQ) || eql_lit?(ECMA262::PUNC_GTEQ) ||
                    eql_lit?(ECMA262::ID_INSTANCEOF) || (!options[:no_in] && eql_lit?(ECMA262::ID_IN)))
        if b = shift_exp(var_env)
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
          raise ParseError.new("unexpceted token", self)
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
    # @param var_env [EnvRecord] Lexical Environment
    # @option options :no_in [Boolean] If set, the parser interpret as RelationExpressionNoIn
    #
    # @return [ECMA262::Base] expression
    #
    # @see ECMA262 11.9
    def equality_exp(var_env, options)
      a = relational_exp(var_env, options)
      return nil if !a

      t = a
      while punc = eql_lit?(ECMA262::PUNC_EQ) ||
                   eql_lit?(ECMA262::PUNC_NEQ) ||
                   eql_lit?(ECMA262::PUNC_SEQ) ||
                   eql_lit?(ECMA262::PUNC_SNEQ)
        if b = relational_exp(var_env, options)
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
          raise ParseError.new("unexpceted token", self)
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
    # @param var_env [EnvRecord] Lexical Environment
    # @option options :no_in [Boolean] If set, the parser interpret as RelationExpressionNoIn
    #
    # @return [ECMA262::Base] expression
    #
    # @see ECMA262 11.10
    def bitwise_and_exp(var_env, options)
      a = equality_exp(var_env, options)
      return nil if !a

      t = a
      while punc = eql_lit?(ECMA262::PUNC_AND)
        if b = equality_exp(var_env, options)
          t = ECMA262::ExpAnd.new(t, b)
        else
          raise ParseError.new("unexpceted token", self)
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
    # @param var_env [EnvRecord] Lexical Environment
    # @option options :no_in [Boolean] If set, the parser interpret as RelationExpressionNoIn
    #
    # @return [ECMA262::Base] expression
    #
    # @see ECMA262 11.10
    def bitwise_xor_exp(var_env, options)
      a = bitwise_and_exp(var_env, options)
      return nil if !a

      t = a
      while punc = eql_lit?(ECMA262::PUNC_XOR)
        if b = bitwise_and_exp(var_env, options)
          t = ECMA262::ExpXor.new(t, b)
        else
          raise ParseError.new("unexpceted token", self)
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
    # @param var_env [EnvRecord] Lexical Environment
    # @option options :no_in [Boolean] If set, the parser interpret as RelationExpressionNoIn
    #
    # @return [ECMA262::Base] expression
    #
    # @see ECMA262 11.10
    def bitwise_or_exp(var_env, options)
      a = bitwise_xor_exp(var_env, options)
      return nil if !a

      t = a
      while punc = eql_lit?(ECMA262::PUNC_OR)
        if b = bitwise_xor_exp(var_env, options)
          t = ECMA262::ExpOr.new(t, b)
        else
          raise ParseError.new("unexpceted token", self)
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
    # @param var_env [EnvRecord] Lexical Environment
    # @return [ECMA262::Base] expression
    # @option options :no_in [Boolean] If set, the parser interpret as RelationExpressionNoIn
    #
    # @see ECMA262 11.11
    def logical_and_exp(var_env, options)
      a = bitwise_or_exp(var_env, options)
      return nil if !a

      t = a
      while punc = eql_lit?(ECMA262::PUNC_LAND)
        if b = bitwise_or_exp(var_env, options)
          t = ECMA262::ExpLogicalAnd.new(t, b)
        else
          raise ParseError.new("unexpceted token", self)
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
    # @param var_env [EnvRecord] Lexical Environment
    # @return [ECMA262::Base] expression
    # @option options :no_in [Boolean] If set, the parser interpret as RelationExpressionNoIn
    #
    # @see ECMA262 11.12
    def logical_or_exp(var_env, options)
      a = logical_and_exp(var_env, options)
      return nil if !a

      t = a
      while punc = eql_lit?(ECMA262::PUNC_LOR)
        if b = logical_and_exp(var_env, options)
          t = ECMA262::ExpLogicalOr.new(t, b)
        else
          raise ParseError.new("unexpceted token", self)
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
    # @param var_env [EnvRecord] Lexical Environment
    #
    # @return [ECMA262::Base] expression
    #
    # @see ECMA262 11.12
    def cond_exp(var_env, options)
      a = logical_or_exp(var_env, options)
      return nil if !a

      if eql_lit?(ECMA262::PUNC_CONDIF)
        if b=assignment_exp(var_env, options) and eql_lit?(ECMA262::PUNC_COLON) and c=assignment_exp(var_env, options)
          ECMA262::ExpCond.new(a, b, c)
        else
          raise ParseError.new("unexpceted token", self)
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
    # @param var_env [EnvRecord] Lexical Environment
    # @option options :no_in [Boolean] If set, the parser interpret as RelationExpressionNoIn
    #
    # @see ECMA262 11.13
    def assignment_exp(var_env, options)
      # AssignmentExpression :
      #  ConditionalExpression
      #  LeftHandSideExpression = AssignmentExpression
      #  LeftHandSideExpression AssignmentOperator AssignmentExpression
      @logger.debug "*** assignment_exp"

      t = cond_exp(var_env, options)
      return nil if t.nil?

      if !t.left_hand_side_exp?
        return  t
      end
      left_hand = t
      punc = peek_lit(:div)
      if punc == ECMA262::PUNC_ASSIGN ||
         punc == ECMA262::PUNC_DIVASSIGN ||
         punc == ECMA262::PUNC_MULASSIGN ||
         punc == ECMA262::PUNC_MODASSIGN ||
         punc == ECMA262::PUNC_ADDASSIGN ||
         punc == ECMA262::PUNC_SUBASSIGN ||
         punc == ECMA262::PUNC_LSHIFTASSIGN ||
         punc == ECMA262::PUNC_RSHIFTASSIGN ||
         punc == ECMA262::PUNC_URSHIFTASSIGN ||
         punc == ECMA262::PUNC_ANDASSIGN ||
         punc == ECMA262::PUNC_ORASSIGN ||
         punc == ECMA262::PUNC_XORASSIGN
        fwd_after_peek
        if b = assignment_exp(var_env, options)
          case punc
          when ECMA262::PUNC_ASSIGN
            ECMA262::ExpAssign.new(left_hand, b)
          when ECMA262::PUNC_DIVASSIGN
            ECMA262::ExpDivAssign.new(left_hand, b)
          when ECMA262::PUNC_MULASSIGN
            ECMA262::ExpMulAssign.new(left_hand, b)
          when ECMA262::PUNC_MODASSIGN
            ECMA262::ExpModAssign.new(left_hand, b)
          when ECMA262::PUNC_ADDASSIGN
            ECMA262::ExpAddAssign.new(left_hand, b)
          when ECMA262::PUNC_SUBASSIGN
            ECMA262::ExpSubAssign.new(left_hand, b)
          when ECMA262::PUNC_LSHIFTASSIGN
            ECMA262::ExpLShiftAssign.new(left_hand, b)
          when ECMA262::PUNC_RSHIFTASSIGN
            ECMA262::ExpRShiftAssign.new(left_hand, b)
          when ECMA262::PUNC_URSHIFTASSIGN
            ECMA262::ExpURShiftAssign.new(left_hand, b)
          when ECMA262::PUNC_ANDASSIGN
            ECMA262::ExpAndAssign.new(left_hand, b)
          when ECMA262::PUNC_ORASSIGN
            ECMA262::ExpOrAssign.new(left_hand, b)
          when ECMA262::PUNC_XORASSIGN
            ECMA262::ExpXorAssign.new(left_hand, b)
          else
            raise "internal error"
          end
        else
          raise ParseError.new("unexpceted token", self)
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
    # @param var_env [EnvRecord] Lexical Environment
    # @option options :no_in [Boolean] If set, the parser interpret as RelationExpressionNoIn
    #
    # @return [ECMA262::Base] expression
    #
    # @see ECMA262 11.14
    def exp(var_env, options)
      # Expression :
      # AssignmentExpression
      # Expression , AssignmentExpression
      @logger.debug "*** expression"

      t = assignment_exp(var_env, options)
      return nil if t.nil?
      while punc = eql_lit?(ECMA262::PUNC_COMMA)
        if b = assignment_exp(var_env, options)
          t = ECMA262::ExpComma.new(t, b)
        else
          raise ParseError.new("unexpceted token", self)
        end
      end
      @logger.debug{
        "*** expression => #{t ? t.to_js : t}"
      }
      t
    end
  end
end

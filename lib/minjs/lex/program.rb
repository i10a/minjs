module Minjs::Lex
  #
  # 14 Program
  #
  module Program
    include Minjs

    # Tests next literals sequence is Program or not.
    #
    # If sequence is Program
    # return ECMA262::Prog object and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @return [ECMA262::Prog] element
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 14
    def program(var_env)
      prog = source_elements(var_env)
      if eof?
        return prog
      else
        raise ParseError.new("unexpceted token", self)
      end
    end

    # Tests next literals sequence is SourceElements or not.
    #
    # If sequence is SourceElements
    # return ECMA262::SourceElements object and
    # forward lexical parser position.
    # Otherwise return nil and position is not changed.
    #
    # @return [ECMA262::SourceElements] element
    #
    # @see http://www.ecma-international.org/ecma-262 ECMA262 14
    def source_elements(var_env)
      prog = []
      while t = source_element(var_env)
        prog.push(t)
      end
      ECMA262::Prog.new(var_env, ECMA262::SourceElements.new(prog))
    end

    def source_element(var_env)
      #eval_lit{
      statement(var_env)
      #} or eval_lit{ => statement
      #  func_declaration(var_env)
      #}
    end

    private :source_element
  end
end


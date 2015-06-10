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
    def program(context)
      prog = source_elements(context)
      if lex.eof?
        return prog
      else
        raise ParseError.new("unexpceted token", lex)
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
    def source_elements(context)
      prog = []
      while t = source_element(context)
        prog.push(t)
      end
      ECMA262::Prog.new(context, ECMA262::SourceElements.new(prog))
    end

    def source_element(context)
      #lex.eval_lit{
      statement(context)
      #} or lex.eval_lit{ => statement
      #  func_declaration(context)
      #}
    end

    private :source_element
  end
end


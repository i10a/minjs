# coding: utf-8
require 'spec_helper'

describe 'Expression' do
  describe 'Unary' do
    it 'is unary operator' do
      js = test_parse <<-EOS
delete a;
void a;
typeof a;
++a;
--a;
+a;
-a;
~a;
!a;
EOS
      expect(js).to eq "delete a;void a;typeof a;++a;--a;+a;-a;~a;!a;"
    end

    it 'is preinc or predec operator' do
      js = test_parse <<-EOS
++a
--b

b
++
c
EOS
      expect(js).to eq "++a;--b;b;++c;"
    end

    it 'cause syntax error' do
      expect {
        js = test_parse 'delete'
      }.to raise_error(Minjs::Lex::ParseError)
      expect {
        js = test_parse 'void'
      }.to raise_error(Minjs::Lex::ParseError)
      expect {
        js = test_parse 'typeof'
      }.to raise_error(Minjs::Lex::ParseError)
      expect {
        js = test_parse '++'
      }.to raise_error(Minjs::Lex::ParseError)
      expect {
        js = test_parse '--'
      }.to raise_error(Minjs::Lex::ParseError)
      expect {
        js = test_parse '+'
      }.to raise_error(Minjs::Lex::ParseError)
      expect {
        js = test_parse '-'
      }.to raise_error(Minjs::Lex::ParseError)
      expect {
        js = test_parse '!'
      }.to raise_error(Minjs::Lex::ParseError)
      expect {
        js = test_parse '~'
      }.to raise_error(Minjs::Lex::ParseError)
    end
  end
end

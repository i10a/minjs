# coding: utf-8
require 'spec_helper'

describe 'Expression' do
  describe 'RemoveParen' do
    it 'is remove paren' do
      c = Minjs::Compressor.new
      c.parse <<-EOS
(!0)+a
EOS
      js = c.remove_paren.to_js
      expect(js).to eq "!0+a;"
    end

    it 'is remove paren' do
      c = Minjs::Compressor.new
      c.parse <<-EOS
// ECMA262 say, expression statement cannot start with an opening curly brace
({a:'b'})
EOS
      js = c.remove_paren.to_js
      expect(js).to eq "({a:\"b\"});"
    end

    it 'is remove paren' do
      c = Minjs::Compressor.new
      c.parse <<-EOS
// ECMA262 say, expression statement cannot start with the function keyword
(function(a,b){console.log(a,b)}(1,2))
EOS
      js = c.remove_paren.to_js
      expect(js).to eq "(function(a,b){console.log(a,b)}(1,2));"
    end
  end
end

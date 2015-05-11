# coding: utf-8
require 'spec_helper'

describe 'Literal' do
  describe 'Numeric' do
    it 'is numeric literal' do
      js = test_parse <<-EOS
console.log(.123)
console.log(.456e10)
console.log(.456e+10)
console.log(.789e-10)
console.log(1.123)
console.log(1.456e10)
console.log(1.456e+10)
console.log(1.789e-10)
console.log(2.)
console.log(2.e10)
console.log(2e10)
console.log(0xabc)
console.log(0XABC)
EOS
      expect(js).to eq "console.log(.123);console.log(.456e10);console.log(.456e10);console.log(.789e-10);console.log(1.123);console.log(1.456e10);console.log(1.456e10);console.log(1.789e-10);console.log(2);console.log(2e10);console.log(2e10);console.log(2748);console.log(2748);"
    end
  end
end

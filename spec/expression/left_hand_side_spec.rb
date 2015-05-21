# coding: utf-8
require 'spec_helper'

describe 'Expression' do
  describe 'LeftHandSide' do
    it 'is left hand side expression' do
      js = test_parse <<-EOS
a;//primary expression
b();//function expression
a[0];
a.b;
new a
new a()
new a(0,1,2)
new new new a
a[0][1][2]
a.b.c.d.e.f
a[0].b.c[2].e
a(1)(2)(3)[4]
EOS
      expect(js).to eq "a;b();a[0];a.b;new a;new a();new a(0,1,2);new new new a;a[0][1][2];a.b.c.d.e.f;a[0].b.c[2].e;a(1)(2)(3)[4];"
    end
    it 'cause syntax error' do
      expect {
        js = test_parse 'a[]'
      }.to raise_error(Minjs::ParseError)
      expect {
        js = test_parse 'a.'
      }.to raise_error(Minjs::ParseError)
      expect {
        js = test_parse 'new'
      }.to raise_error(Minjs::ParseError)
      expect {
        js = test_parse 'a['
      }.to raise_error(Minjs::ParseError)
      expect {
        js = test_parse 'a('
      }.to raise_error(Minjs::ParseError)
    end
  end
end

# coding: utf-8
require 'spec_helper'

describe 'Compression' do
  describe 'ReduceIf' do
    it 'reduce nested "if" statement' do
      c = test_compressor
      c.parse <<-EOS
if(a)
if(b)
break;
EOS
      js = c.reduce_if.to_js
      expect(js).to eq "if(a&&b)break;"
    end
    it 'reduce if' do
      c = test_compressor
      c.parse <<-EOS
if(a);
if(b){}
if(c);else;
if(d){}else{}
if(e)aa;else;
if(f)bb;else{}
if(g)
  if(h)
    hh;
  else
    ;
else
  gg;
EOS
      js = c.reduce_if.to_js
      expect(js).to eq "a;b;c;d;if(e)aa;if(f)bb;if(g){if(h)hh}else gg;"
    end
    it 'reduce if' do
      c = test_compressor
      c.parse <<-EOS
if(a);else aaa;
if(a){}else aaa;
EOS
      js = c.reduce_if.to_js
      expect(js).to eq "if(!a)aaa;if(!a)aaa;"
    end
  end
end

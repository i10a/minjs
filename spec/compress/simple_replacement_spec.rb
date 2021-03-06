# coding: utf-8
require 'spec_helper'

describe 'Compression' do
  describe 'SimpleReplacement' do
    it 'replace to shorter one' do
      c = test_compressor
      c.parse <<-EOS
true;
false;
if(1)a;
if(0)a;
if(0)a;else b;
while(1);
EOS
      js = c.simple_replacement.to_js
      expect(js).to eq "(!0);(!1);a;b;for(;;);"
    end

    it 'replace to shorter one' do
      c = test_compressor
      c.parse <<-EOS
if(1&&"0"&&/a/&&[]&&{})a;
if(""||1)b;
if(1&&false)c;
if(""||null||0)d;
EOS
      js = c.simple_replacement.to_js
      expect(js).to eq "a;b;"
    end

    it 'replace array argument to prop' do
      c = test_compressor
      c.parse <<-EOS
A["B"];
A["$"];
A["あ"];
A["3.14"];
A[""];
EOS
      js = c.simple_replacement.to_js
      expect(js).to eq 'A.B;A.$;A.あ;A[3.14];A[""];'
    end
    it 'add and remove paren' do
      c = test_compressor
      c.parse <<-EOS
new a()() // mean => (new a()) () => (new a)()
EOS
      js = c.simple_replacement.to_js
      expect(js).to eq "(new a)();"
    end
  end
end


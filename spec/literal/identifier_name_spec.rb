# coding: utf-8
require 'spec_helper'

describe 'Literal' do
  describe 'IdentifierName' do
    it 'is identifier name' do
      js = test_parse <<-'EOS'
a=1;
$=2;
_=3;
console.log(\u0061);//same as 'a'
ab0=1;
$$$=2;
__0=3;
console.log(\u0061\u0062\u0030);//same as 'ab0'
EOS
      expect(js).to eq "a=1;$=2;_=3;console.log(a);ab0=1;$$$=2;__0=3;console.log(ab0);"
    end

    it 'is identifier name' do
      js = test_parse <<-"EOS"
\u0100=4;// Unicode(0100) Lu
\u0101=5;// Unicode(0101) Ll
\u01c5=6;// Unicode(01c5) Lt
\u02b0=7;// Unicode(02b0) Lm
\u3042=6;// unicode(3042) Lo
\u16ee=8;// Unicode(16ee) Nl
console.log(あ)
EOS
      expect(js).to eq "Ā=4;ā=5;ǅ=6;ʰ=7;あ=6;ᛮ=8;console.log(あ);"
    end

    it 'is identifier name' do
      js = test_parse <<-"EOS"
\u3042\u309a=9;// Unicode(309a) Mn
\u3042\u0903=10;// Unicode(0903) Mc
\u3042\u0903=11;// Unicode(0903) Mc
\u3042\u0660=12;// Unicode(0903) Nd
\u3042\u203f=13;// Unicode(203f) Pc
EOS
      expect(js).to eq "あ゚=9;あः=10;あः=11;あ٠=12;あ‿=13;"
    end
  end
end

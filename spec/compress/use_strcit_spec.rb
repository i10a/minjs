require 'spec_helper'

describe 'Compression' do
  describe 'UseStrict' do
    it 'remains "use strict" at the top of program' do
      c = test_compressor
      c.parse <<-EOS
"use strict"
function zz(){}
EOS
      js = c.reduce_if.to_js
      expect(js).to eq "\"use strict\";function zz(){}"
    end
    it 'remains "use strict" at the top of program' do
      c = test_compressor
      c.parse <<-EOS
"use strict"
var a=1;
EOS
      js = c.reduce_if.to_js
      expect(js).to eq "\"use strict\";var a=1;"
    end
  end
end

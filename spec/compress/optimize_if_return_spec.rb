# coding: utf-8
require 'spec_helper'

describe 'Compression' do
  describe 'OptimizeIfReturn' do
    it 'convert if statment to return statement' do
      c = test_compressor
      c.parse <<-EOS
if(a)return b;return c;
EOS
      js = c.optimize_if_return.to_js
      expect(js).to eq "if(a)return b;else return c;"
    end

    it 'remove else block' do
      c = test_compressor
      c.parse <<-EOS
if(a)return b;else c;
EOS
      js = c.optimize_if_return2.to_js
      expect(js).to eq "if(a)return b;c;"
    end
  end
end


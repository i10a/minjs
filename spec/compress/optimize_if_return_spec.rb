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
      expect(js).to eq "return a?b:c;"
    end

    it 'convert if statment to return statement' do
      c = test_compressor
      c.parse <<-EOS
if(a)return b;
if(c)return d;
if(e)return f;
EOS
      js = c.optimize_if_return.to_js
      expect(js).to eq "return a?b:c?d:e?f:void 0;"
    end

    it 'remove else clause' do
      c = test_compressor
      c.parse <<-EOS
if(a)return b;else c;
EOS
      js = c.optimize_if_return2.to_js
      expect(js).to eq "if(a)return b;c;"
    end

    it 'remove then clause' do
      c = test_compressor
      c.parse <<-EOS
if(a)b;else return c;
EOS
      js = c.optimize_if_return2.to_js
      expect(js).to eq "if(!a)return c;b;"
    end
  end
end


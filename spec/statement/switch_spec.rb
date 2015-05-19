require 'spec_helper'

describe 'Statement' do
  describe 'Switch' do
    it 'is switch statement' do
      js = test_parse <<-EOS
$=0;
switch($)
{
        case 0:
        console.log(0);
        break;

        case 1:
        console.log(1);
        break;

        default:
        console.log("default");
        break;
}
EOS
      expect(js).to eq "$=0;switch($){case 0:console.log(0);break;case 1:console.log(1);break;default:console.log(\"default\");break}";
    end
  end
end

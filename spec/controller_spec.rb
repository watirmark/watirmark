require_relative 'spec_helper'

describe Watirmark::WebPage::Controller do

  class TestView < Page
    keyword(:text_field) { browser.text_field(:name, 'text_field') }
    keyword(:select_list) { browser.select_list(:name, 'select_list') }
    keyword(:another_text_field) { browser.text_field(:id, 'validate1') }
  end

  class TestController < Watirmark::WebPage::Controller
    @view = TestView

    def initialize(*args)
      super
      @model.text_field = 'foobar'
    end
  end

  class VerifyView < Page
    keyword(:validate1) { browser.text_field(:id, 'validate1') }
    keyword(:validate2) { browser.text_field(:id, 'validate2') }
    keyword(:validate3) { browser.text_field(:id, 'validate3') }
    keyword(:validate4) { browser.select_list(:id, 'validate3') }
    keyword(:checkbox) { browser.checkbox(:id, 'checkbox') }

    verify_keyword(:label1) { browser.td(:id, 'label1') }
    verify_keyword(:value1) { browser.td(:id, 'value1') }
    populate_keyword(:populate1) { browser.text_field(:id, 'validate4') }
    populate_keyword(:populate2) { browser.td(:id, 'value1') }

    private_keyword(:private_validate1) { browser.text_field(:id, 'validate1') }
    navigation_keyword(:click_submit) { browser.button(:id, 'Submit').click }
  end

  class VerifyController < Watirmark::WebPage::Controller
    @view = VerifyView
  end

  class TestControllerSubclass < TestController;
  end

  class Element
    attr_accessor :value

    def initialize(x)
      @value = x
    end

    # stub this out because we're not actually
    # using a real HTML page for these tests
    def wait_until_present
      self
    end
  end

  class SomeView < Page

    keyword(:a) { Element.new :a }
    keyword(:b) { Element.new :b }
    keyword(:c) { Element.new :c }
    keyword(:d) { Element.new :d }
    keyword(:e) { method :e }
    keyword(:radio_map,
            ['M'] => 'male',
            [/f/i] => 'female'
    ) { Page.browser.radio(:name, 'sex') }
  end

  class SomeController < Watirmark::WebPage::Controller
    @view = SomeView
  end

  before :all do
    @controller = Class.new(TestController) do
      public :value
    end.new
    @keyword = :text_field
    @keyed_element = Watirmark::KeyedElement.new(@controller, :keyword => @keyword)
    @html = File.expand_path(File.dirname(__FILE__) + '/html/controller.html')
    Page.browser.goto "file://#{@html}"
  end

  before :each do
    Page.browser.refresh #reset page before each test
  end

  it 'should supportradio maps in controllers' do
    lambda {
      SomeController.new(:radio_map => 'f').populate_data
    }.should_not raise_error
  end

  it 'should be able to create and use a new keyword' do
    @keyword.should == :text_field
    TestView.new.send("#{@keyword}=", 'test')
    lambda { @controller.check(@keyword, 'test') }.should_not raise_error(Watirmark::VerificationException)
  end

  it 'should be able to populate' do
    module ControllerTest
      class PopulateController < Watirmark::WebPage::Controller
        @view = TestView
      end
    end
    ControllerTest::PopulateController.new(
        :text_field => 'test',
        :select_list => 'b',
        :another_text_field => 'nil'
    ).populate_data
    v = TestView.new
    v.text_field.value.should == 'test'
    v.select_list.value.should == 'b'
    v.another_text_field.value.should == ''
  end

  it 'should be be able to interpret use value' do
    @controller.value(@keyed_element).should == 'foobar'
  end

  it 'should support override method to value' do
    class TestController
      def text_field_value
        'override'
      end
    end
    @controller.value(Watirmark::KeyedElement.new(TestController.new, :keyword => @keyword)).should == 'override'
  end

  it 'should support override method for verification' do
    def @controller.verify_text_field;
      'verify';
    end

    @controller.expects(:verify_text_field).returns('verify').once
    @controller.verify_data
  end

  it 'should support keyword before and after methods' do
    def @controller.before_text_field;
      'before';
    end

    def @controller.after_text_field;
      'after';
    end

    @controller.expects(:before_text_field).returns('before').once
    @controller.expects(:after_text_field).returns('after').once
    @controller.populate_data {}
  end

  it 'should propogate page declaration to subclasses' do
    TestControllerSubclass.view.should == TestView
  end

  it 'should throw a Watirmark::VerificationException when a verification fails' do
    lambda {
      VerifyController.new(:validate1 => '2').verify_data
    }.should raise_error(Watirmark::VerificationException, "validate1: expected '2' (String) got '1' (String)")
  end

  it 'should not throw an exception when a verification succeeds' do
    VerifyController.new(:validate2 => 'a').verify_data
  end

  it 'should not throw an exception when many verifications succeed' do
    VerifyController.new(:validate1 => '1', :validate2 => 'a', :validate3 => 1.1).verify_data
  end

  it 'should only throw one validation exception when there are 3 three problems' do
    lambda {
      VerifyController.new(:validate1 => 'z', :validate2 => 'y', :validate3 => 'x').verify_data
    }.should raise_error(Watirmark::VerificationException)
  end

  it 'should throw an exception when verifying a verify_keyword fails' do
    lambda {
      VerifyController.new(:label1 => 'text').verify_data
    }.should raise_error(Watirmark::VerificationException, "label1: expected 'text' (String) got 'numbers' (String)")
  end

  it 'should not throw an exception when verifying a verify_keyword succeeds' do
    VerifyController.new(:label1 => 'numbers', :value1 => 1).verify_data
  end

  it 'should not throw an exception when populating with a verify_keyword' do
    VerifyController.new(:label1 => 'string').populate_data
  end

  it 'should throw an exception when populating a populate_keyword fails' do
    lambda {
      VerifyController.new(:populate2 => '32').populate_data
    }.should raise_error(NoMethodError)
  end

  it 'should not throw an exception when populating a populate_keyword succeeds' do
    VerifyController.new(:populate1 => '3.14159').populate_data
  end

  it 'should not throw an exception when verifying with a populate_keyword' do
    VerifyController.new(:populate1 => 'void').verify_data
  end

  it 'should not populate a private_keyword successfully' do
    c = VerifyController.new(:validate1 => 'hello')
    c.populate_data
    VerifyController.new(:private_validate1 => 'goodbye').populate_data
    c.verify_data
  end

  it 'should not verify a private_keyword successfully' do
    c = VerifyController.new(:private_validate1 => 'hello')
    VerifyController.new(:validate1 => 'goodbye').populate_data
    c.verify_data
  end

  it 'should not throw an exception when populating or verifying a private_keyword fails' do
    c = VerifyController.new(:private_validate1 => 'goodbye')
    c.populate_data
    c.model.update(:private_validate1 => 'hello')
    c.verify_data
  end

  it 'should not throw an exception when populating or verifying a navigation_keyword fails' do
    c = VerifyController.new(:button1 => 'Cancel')
    c.populate_data
    c.model.update(:button1 => 'Submit')
    c.verify_data
  end

  it 'false should be a valid keyword value' do
    c = VerifyController.new(:checkbox => true)
    c.populate_data
    VerifyView.new.checkbox.set?.should be_true
    c.model.update(:checkbox => false)
    c.populate_data
    VerifyView.new.checkbox.set?.should be_false
  end
end

describe "controllers should be able to detect and use embedded models" do
  before :all do
    class MyView < Page
      keyword(:element) { @@element }
    end
    @controller = Class.new Watirmark::WebPage::Controller do
      @view = MyView
    end
    class User < Watirmark::Model::Factory
      keywords :first_name
    end

    class Login < Watirmark::Model::Factory
      keywords :first_name
    end

    class Password < Watirmark::Model::Factory
      keywords :password
    end
    @password = Password.new
    @login = Login.new
    @login.add_model @password
    @model = User.new(:first_name => 'first')
    @model.add_model @login
  end

  it 'should be able to see itself' do
    @model.find(User).should == @model
  end

  it 'should be able to see a sub_model' do
    @model.find(Login).should == @login
  end

  it 'should be able to see a nested sub_model' do
    @model.find(Password).should == @password
  end
end

describe "controllers should create a default model if one exists" do
  before :all do
    class MyView < Page
      private_keyword(:element)
    end
    class MyModel < Watirmark::Model::Factory
      keywords :element
    end
    @controller = Class.new Watirmark::WebPage::Controller do
      @view = MyView
      @model = MyModel
    end
  end

  it 'should be able to see itself' do
    c = @controller.new
    c.model.should be_kind_of(MyModel)
  end
end


describe "Similar Models" do

  before :all do
    class SomeView < Page

      keyword(:a) { Element.new :a }
      keyword(:b) { Element.new :b }
      keyword(:c) { Element.new :c }
      keyword(:d) { Element.new :d }
      keyword(:e) { method :e }
      keyword(:radio_map,
              ['M'] => 'male',
              [/f/i] => 'female'
      ) { Page.browser.radio(:name, 'sex') }
    end

    class ModelA < Watirmark::Model::Factory
      keywords SomeView.keywords
      defaults do
        radio_map { 'M' }
      end
    end

    class ModelC < Watirmark::Model::Factory
      keywords SomeView.keywords
      model ModelA
    end

    class ModelB < Watirmark::Model::Factory
      keywords SomeView.keywords
      model_type ModelA
      defaults do
        radio_map { 'f' }
      end
    end

    class ModelD < Watirmark::Model::Factory
      keywords SomeView.keywords
      model ModelB
    end

    class ModelE < Watirmark::Model::Factory
      keywords SomeView.keywords
      model ModelD
    end

    class ModelF < Watirmark::Model::Factory
      keywords SomeView.keywords
      model_type ModelA
    end

    class ModelG < Watirmark::Model::Factory
      keywords SomeView.keywords
      model ModelF
    end

    class ModelH < Watirmark::Model::Factory
      keywords SomeView.keywords
    end

    class SomeController < Watirmark::WebPage::Controller
      @model = ModelA
      @view = SomeView
      public :value
    end

    class TestNoModelController < Watirmark::WebPage::Controller
      @view = SomeView
    end


  end

  it 'should use the similar modelA' do
    @controller = SomeController.new(ModelD.new)
    @controller.model.should be_kind_of ModelB
    @controller.supermodel.should be_kind_of ModelD
  end

  it 'should use the top model' do
    @controller = SomeController.new(ModelB.new)
    @controller.model.should be_kind_of ModelB
    @controller.supermodel.should be_kind_of ModelB
  end

  it 'should use parent model' do
    @controller = SomeController.new(ModelC.new)
    @controller.model.should be_kind_of ModelA
    @controller.supermodel.should be_kind_of ModelC
  end

  it 'should call the smallest child similar to the model in controller' do
    @controller = SomeController.new(ModelE.new)
    @controller.model.should be_kind_of ModelB
    @controller.supermodel.should be_kind_of ModelE

  end

  it 'should select the correct model when base model has 2 similar models' do
    @controller = SomeController.new(ModelG.new)
    @controller.model.should be_kind_of ModelF
    @controller.supermodel.should be_kind_of ModelG

    @controller = SomeController.new(ModelF.new)
    @controller.model.should be_kind_of ModelF
    @controller.supermodel.should be_kind_of ModelF
  end

  it 'should use the supermodel as a model if a controller model is not defined' do
    @controller = TestNoModelController.new(ModelE.new)
    @controller.model.should be_kind_of ModelE
    @controller.supermodel.should be_kind_of ModelE
  end

  it 'should use passed in model as @model when model_type is not defined' do
    @controller = SomeController.new(ModelH.new)
    @controller.model.should be_kind_of ModelH
    @controller.supermodel.should be_kind_of ModelH
  end

  it 'should allow us to override the default model' do
    @controller = SomeController.new(ModelH.new)
    @controller.model.should be_kind_of ModelH
    @controller.model = ModelA.new
    @controller.model.should be_kind_of ModelA
  end

end

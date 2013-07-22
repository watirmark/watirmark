module Watirmark
  module PageDefinition
    attr_accessor :kwds, :perms, :kwd_metadata

    @@browser = nil

    def inherited(klass)
      add_superclass_keywords_to_subclass(klass)
      add_superclass_keyword_metadata_to_subclass(klass)
    end

    def keyword(name, map=nil, &block)
      create_new_keyword(name, map, permissions={:populate => true, :verify => true}, &block)
    end

    def populate_keyword(name, map=nil, &block)
      create_new_keyword(name, map, permissions={:populate => true}, &block)
    end

    def verify_keyword(name, map=nil, &block)
      create_new_keyword(name, map, permissions={:verify => true}, &block)
    end

    def private_keyword(name, map=nil, &block)
      create_new_keyword(name, map, &block)
    end

    alias :navigation_keyword :private_keyword

    # Create an alias to an existing keyword
    def keyword_alias(keyword_alias_name, keyword_name)
      keyword_data = @kwd_metadata[self.to_s][keyword_name]
      create_new_keyword(keyword_alias_name, keyword_data[:map], keyword_data[:permissions], &keyword_data[:block])
    end

    def browser
      @@browser ||= Watirmark::Session.instance.openbrowser
    end

    def browser=(x)
      @@browser = x
    end

    def browser_exists?
      !!@@browser
    end

    def keywords
      @kwds ||= Hash.new { |h, k| h[k] = Array.new }
      @kwds.values.flatten.uniq.sort_by { |key| key.to_s }
    end

    def native_keywords
      @kwds ||= Hash.new { |h, k| h[k] = Array.new }
      @kwds[self.to_s].sort_by { |key| key.to_s }
    end

    def keyword_metadata
      @kwd_metadata ||= nested_hash
      @kwd_metadata.values.inject(:merge)
    end

    private
    def nested_hash
      Hash.new { |h, k| h[k] = Hash.new { |h, k| h[k]=Hash.new } }
    end

    def create_new_keyword(name, map=nil, permissions, &block)
      keyword_name = name.to_sym
      add_to_keywords(keyword_name)
      add_keyword_metadata(keyword_name, map, permissions, block)
    end

    def add_keyword_metadata(name, map, permissions, block)
      @kwd_metadata ||= nested_hash
      @kwd_metadata[self.to_s][name][:keyword] = name
      @kwd_metadata[self.to_s][name][:map] = map
      @kwd_metadata[self.to_s][name][:permissions] = permissions
      @kwd_metadata[self.to_s][name][:block] = block
    end

    def add_to_keywords(method_sym)
      @kwds ||= Hash.new { |h, k| h[k] = Array.new }
      @kwds[self.to_s] << method_sym unless @kwds.include?(method_sym)
    end

    def add_superclass_keywords_to_subclass(klass)
      update_subclass_variables(klass, method='kwds', default=Hash.new { |h, k| h[k] = Array.new })
    end

    def add_superclass_keyword_metadata_to_subclass(klass)
      update_subclass_variables(klass, method='kwd_metadata', default=Hash.new { |h, k| h[k] = Hash.new { |h, k| h[k] = Hash.new } })
    end

    def update_subclass_variables(klass, method, default)
      var = self.send(method)
      if var
        klass.send("#{method}=", default) unless klass.send(method)
        var.each_key do |k|
          klass.send(method).store(k, var.fetch(k).dup)
        end
      end
    end
  end

end

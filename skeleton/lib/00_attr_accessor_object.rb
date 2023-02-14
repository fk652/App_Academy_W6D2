class AttrAccessorObject
  def self.my_attr_accessor(*names)
    names.each do |name|
      var_name = name.to_s

      # define a setter
      define_method(var_name) do 
        self.instance_variable_get("@#{var_name}")
      end

      #define a getter
      getter_name = "#{var_name}="
      define_method(getter_name) do |new_val|
        self.instance_variable_set("@#{var_name}", new_val)
      end
    end
  end
end

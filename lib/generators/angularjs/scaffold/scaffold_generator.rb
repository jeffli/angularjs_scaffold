require 'rails/generators'
require 'rails/generators/generated_attribute'
require 'pp'

module Angularjs
  class ScaffoldGenerator < Rails::Generators::Base
    SQL = 'sql'
    NO_SQL = 'no_sql'
    BLACKLIST_ATTRIBUTES = %w[id _id _type created_at updated_at]

    source_root File.expand_path('../templates', __FILE__)
    argument :controller_name, :type => :string

    # HACK ALERT
    # Since I can't find a thor method that checks for the existence of a file,
    # I am forced to hackery.  I assume that the language selected was 'javascript'.
    # I attempt to add a blank line to the end of 'app/assets/javascripts/routes.js.erb', 
    # and if that fails, then I catch the exception and assume that the selected language option is 'coffeescript'
    def language_option
      answer = 'javascript'
      begin
        append_to_file "app/assets/javascripts/routes.js.erb", "\n"
      rescue Exception
        answer = 'coffeescript'
      end
      answer
    end 

    def init_vars
      @model_name = controller_name.singularize #"Post"
      @controller = controller_name #"Posts"
      @resource_name = @model_name.demodulize.underscore #post
      @plural_model_name = @resource_name.pluralize #posts
  
      if database_type == SQL 
        @model_name.constantize[method].
          each{|c|
            (['name','title'].include?(c.name)) ? @resource_legend = c.name.capitalize : ''}
        @resource_legend = 'ID' if @resource_legend.blank?
      else
        @resource_legend = 'List'
      end

      @language = language_option # 'coffeescript or javascript'
    end

    # the readable attributes that can be shown in the show page
    def readable_attributes    
      if database_type == SQL 
        columns
      else 
        record = @model_name.constantize.fields
  
        excluded_column_names = BLACKLIST_ATTRIBUTES

        record.collect{|c| c[1]}.
          reject{|c| excluded_column_names.include?(c.name) }.
          collect{|c|
            ::Rails::Generators::GeneratedAttribute.
              new(c.name, c.type.to_s)}
        end      
    end

    # the attributes that are writable to database, for new and edit page
    def writable_attributes
      if database_type == SQL 
        columns
      else 
        model = @model_name.constantize

        writables = (model.accessible_attributes - model.protected_attributes).to_a - [""]
        writables = model.fields.keys if writables.blank?

        writables = writables - BLACKLIST_ATTRIBUTES
        
        model.fields.collect{|c| c[1]}.
          reject{|c| not writables.include?(c.name) }.
          collect{|c|
            ::Rails::Generators::GeneratedAttribute.
              new(c.name, c.type.to_s)}
        end      
    end
 
    def generate
      remove_file "app/assets/stylesheets/scaffolds.css.scss"
      append_to_file "app/assets/javascripts/application.js",
        "//= require #{@plural_model_name}_controller \n"
      append_to_file "app/assets/javascripts/application.js",
        "//= require #{@plural_model_name} \n"
      if @language == 'coffeescript'
        insert_into_file "app/assets/javascripts/routes.coffee.erb",
        ", \'#{@plural_model_name}\'", :after => "'ngCookies'"
        insert_into_file "app/assets/javascripts/routes.coffee.erb",
%{when("/#{@plural_model_name}", 
    controller: #{@controller}IndexCtrl
    templateUrl: "<%= asset_path(\"#{@plural_model_name}/index.html\") %>"
  ).when("/#{@plural_model_name}/new",
    controller: #{@controller}CreateCtrl
    templateUrl: "<%= asset_path(\"#{@plural_model_name}/new.html\") %>"
  ).when("/#{@plural_model_name}/:id",
    controller: #{@controller}ShowCtrl
    templateUrl: "<%= asset_path(\"#{@plural_model_name}/show.html\") %>"
  ).when("/#{@plural_model_name}/:id/edit",
    controller: #{@controller}EditCtrl
    templateUrl: "<%= asset_path(\"#{@plural_model_name}/edit.html\") %>"
  ).}, :before => 'otherwise'
      else
        insert_into_file "app/assets/javascripts/routes.js.erb",
        ", '#{@plural_model_name}'", :after => "'ngCookies'"
        insert_into_file "app/assets/javascripts/routes.js.erb",
%{    when('/#{@plural_model_name}', {controller:#{@controller}IndexCtrl,
         templateUrl:'<%= asset_path("#{@plural_model_name}/index.html") %>'}).
    when('/#{@plural_model_name}/new', {controller:#{@controller}CreateCtrl,
                templateUrl:'<%= asset_path("#{@plural_model_name}/new.html") %>'}).
    when('/#{@plural_model_name}/:id', {controller:#{@controller}ShowCtrl,
         templateUrl:'<%= asset_path("#{@plural_model_name}/show.html") %>'}).
    when('/#{@plural_model_name}/:id/edit', {controller:#{@controller}EditCtrl,
         templateUrl:'<%= asset_path("#{@plural_model_name}/edit.html") %>'}).\n
}, :before => 'otherwise'
      end
      
      inject_into_class "app/controllers/#{@plural_model_name}_controller.rb",
        "#{@controller}Controller".constantize, "respond_to :json\n"
      template "new.html.erb",
        "app/assets/templates/#{@plural_model_name}/new.html.erb"
      template "edit.html.erb",
        "app/assets/templates/#{@plural_model_name}/edit.html.erb"
      template "show.html.erb",
        "app/assets/templates/#{@plural_model_name}/show.html.erb"
      template "index.html.erb",
        "app/assets/templates/#{@plural_model_name}/index.html.erb"
      
      if @language == 'coffeescript'
        template "cs/plural_model_name.js.coffee", "app/assets/javascripts/#{@plural_model_name}.js.coffee"
        template "cs/plural_model_name_controller.js.coffee",
          "app/assets/javascripts/#{@plural_model_name}_controller.js.coffee"
      else
        template "js/plural_model_name.js", "app/assets/javascripts/#{@plural_model_name}.js"
        template "js/plural_model_name_controller.js",
          "app/assets/javascripts/#{@plural_model_name}_controller.js"
        # remove the default .js.coffee file added by rails.
        remove_file "app/assets/javascripts/#{@plural_model_name}.js.coffee"
      end
    end
 
 private

    def database_type
      unless @db_type 
        @db_type = controller_name.singularize.constantize.respond_to?('columns') ? SQL : NO_SQL
      end
      @db_type
    end

    def columns      
        excluded_column_names = BLACKLIST_ATTRIBUTES

        @model_name.constantize.columns.
          reject{|c| excluded_column_names.include?(c.name) }.
          collect{|c| ::Rails::Generators::GeneratedAttribute.
                  new(c.name, c.type)}  
    end

  end
end

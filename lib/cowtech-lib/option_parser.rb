# encoding: utf-8
#
#	cowtech-lib
#	Author: Shogun <shogun_panda@me.com>
#	Copyright © 2011 and above Shogun
# Released under the MIT License, which follows.
#
# The MIT License
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#

require "getoptlong"

module Cowtech
  module Lib
    # A class which parse commandline options.
    # @author Shogun
    class OptionParser
      # The specified options
      attr_accessor :options
    
      # The full command line provided
      attr_reader :cmdline
    
      # The messages for the help message
      attr_reader :messages
    
      # The other (non-option) provided args
      attr_reader :args
    
      # Add or replace an option to the parser. Every argument is optional (in the form ATTR => VALUE) with the exception of :name, :short and :long.
      # 
      # Arguments:
      # * <em>:name</em>: Option name
      # * <em>:short</em>: Option short form, can begin with "-"
      # * <em>:long</em>: Option long form, can begin with "--"
      # * <em>:type</em>: Option type, valid values are:
      # * <em>:bool</em>: Boolean option
      # * <em>:string</em>: Option with string argument
      # * <em>:int</em>: Option with int argument
      # * <em>:float</em>: Option with float argument
      # * <em>:choice</em>: Option with string argument that must be valitated from a list of patterns
      # * <em>:list</em>: Option with a list of string argument
      # * <em>:action</em>: Option with an associated action
      # * <em>:help</em>: Option description
      # * <em>:choices</em>: Option valid choice (list of regexp), only used with the :choice type
      # * <em>:action</em>: Option action block, only used with the :action type
      # * <em>:meta</em>: Option meta variable for description
      # * <em>:default</em>: Option default value
      # * <em>:required</em>: Whether the option is required
      # * <em>:priority</em>: Priority for the option. Used only on the help message to sort (by increasing priority) the options.
      def <<(options)
        options = [options] unless options.is_a?(Array)

        options.each do |option|
          @console.fatal(:msg => "Every attribute must be an Hash.", :dots => false) unless option.is_a?(Hash)
      
          # Use symbols for names
          option[:name] = option[:name].to_sym
        
          # Add the default type, which is :string
          option[:type] ||= :string

          # Check if type is valid
          @console.fatal(:msg => "Invalid option type #{option[:type]} for option #{option[:name]}. Valid type are the following:\n\t#{@@valid_types.keys.join(", ")}.", :dots => false) unless @@valid_types.keys.include?(option[:type])
        
          # Adjust the default value
          case option[:type]
            when :bool then
              option[:default] = false unless option[:default] == true
            when :action then
              option[:required] = false
            else
              option[:default] = @@valid_types[option[:type]][1] unless option[:default].is_a?(@@valid_types[option[:type]][0]) == true || option[:default] != nil
          end

          # Adjust priority
          option[:priority] = option[:priority].to_s.to_i unless option[:priority].is_a?(Integer)
      
          # Prepend dashes
          option[:short] = "-" + option[:short] unless option[:short] =~ /^-/
          while not option[:long] =~ /^--/ do option[:long] = "-" + option[:long] end
          @console.fatal(:msg => "Invalid short form \"#{option[:short]}\".", :dots => false) unless option[:short] =~ /^-[0-9a-z]$/i
          @console.fatal(:msg => "Invalid long form \"#{option[:long]}\".", :dots => false) unless option[:long] =~ /^--([0-9a-z-]+)$/i
      
          # Check for choices if the type is choices
          if option[:type] == :choice then
            if option[:choices] == nil then
              @console.fatal(:msg => "Option \"#{option[:name]}\" of type choice requires a valid choices list (every element should be a regular expression).")
            else
              option[:choices].collect! do |choice| Regexp.new(choice) end
            end
          end
      
          # Check that action is a block if the type is action
          @console.fatal("Option \"#{option[:name]}\" of type action requires a action block.") if option[:type] == :action && (option[:action] == nil || !option[:action].is_a?(Proc.class))

          # Check for uniqueness of option and its forms
          @console.fatal("An option with name \"#{option[:name]}\" already exists.", :dots => false) if @inserted[:name].include?(option[:name])
          @console.fatal("An option with short or long form \"#{option[:short]}\" already exists.", :dots => false) if @inserted[:short].include?(option[:short])
          @console.fatal("An option with short or long form \"#{option[:long]}\" already exists.", :dots => false) if @inserted[:long].include?(option[:long]) 

          # Save
          @options[option[:name]] = option
          @options_map[option[:long]] = option[:name]
          @inserted[:name].push(option[:name])
          @inserted[:short].push(option[:short])
          @inserted[:long].push(option[:long])
        end
      end
  
      # Parse the command line.
      # 
      # Arguments:
      # * <em>ignore_unknown</em>: Whether ignore unknown options
      # * <em>ignore_unknown</em>: Whether ignore help options
      def parse(args = nil)
        args ||= {}
        # Create options
        noat = [:bool, :action]
        sopts = @options.each_value.collect do |option| [option[:long], option[:short], noat.include?(option[:type]) ? GetoptLong::NO_ARGUMENT : GetoptLong::REQUIRED_ARGUMENT] end

        opts = GetoptLong.new(*sopts)
        opts.quiet = true
      
        # Parse option
        begin
          opts.each do |given, arg|
            optname = @options_map[given]
            option = @options[optname]
            value = nil

          
            # VALIDATE ARGUMENT DUE TO CASE
            case option[:type]
              when :string then
                value = arg
              when :int then
                if arg.strip =~ /^(-?)(\d+)$/ then value = arg.to_i(10) else @console.fatal(:msg => "Argument of option \"#{given}\" must be an integer.", :dots => false) end
              when :float then
                if arg.strip =~ /^(-?)(\d*)(\.(\d+))?$/ and arg.strip() != "." then value = arg.to_f else @console.fatal(:msg => "Argument of option \"#{given}\" must be a float.", :dots => false) end
              when :choice then
                if @options[optname].choices.find_index { |choice| arg =~ choice } then value = arg else @console.fatal(:msg => "Invalid argument (invalid choice) for option \"#{given}\".", :dots => false) end
              when :list then
                value = arg.split(",")
              else
                value = true
            end
          
            @options[optname][:value] = value
          end
        rescue StandardError => exception
          if exception.message =~ /.+-- (.+)$/ then 
            given = $1

            if exception.is_a?(GetoptLong::InvalidOption) then
              @console.fatal(:msg => "Unknown option \"#{given}\".", :dots => false) unless args[:ignore_unknown]
            elsif exception.is_a?(GetoptLong::MissingArgument) then
              @console.fatal(:msg => "Option \"-#{given}\" requires an argument.", :dots => false)
            end
          else
            @console.fatal("Unexpected error: #{exc.message}.")
          end
        end
      
        # SET OTHER ARGUMENTS
        @args = ARGV

        # CHECK IF HELP WAS REQUESTED
        if self.provided?("help") and !args[:ignore_help] then
          self.print_help
          exit(0)
        end
      
        # NOW CHECK IF SOME REQUIRED OPTION WAS NOT SPECIFIED OR IF WE HAVE TO EXECUTE AN ACTION
        @inserted[:name].each do |key|
          option = @options[key]

          if option[:required] == true and option[:value] == nil then
            @console.fatal(:msg => "Required option \"#{opt.name}\" not specified.", :dots => false)          
          elsif option[:value] == true and option[:type] == :action then
            option.action.call
          end
        end      
      end

      # Check if an option is defined.
      # Arguments:
      # * <em>name</em>: Option name
      # Returns: <em>true</em> if options is defined, <em>false</em> otherwise. 
      def exists?(name)
        name = name.to_sym
        @options.keys.include?(name)
      end
    
      # Check if the user provided the option.
      # Arguments:
      # * <em>name</em>: Option name
      # Returns: <em>true</em> if options was provided, <em>false</em> otherwise. 
      def provided?(name)
        name = name.to_sym
        (@options[name] || {})[:value] != nil
      end

      # Get a list of value for the requested options.
      # Arguments:
      # * <em>name</em>: Options name
      # * <em>name</em>: Default value if option was not provided.
      # Returns: The option value
      def get(name, default = nil)
        name = name.to_sym

        if @options[name][:value] != nil then
          @options[name][:value]
        elsif default != nil then
          default
        else
          @options[name][:default]
        end
      end
    
      # Get a list of value for the requested options.
      # Arguments:
      # * <em>options</em>: Options list
      # Returns: If a single argument is provided, only a value is returned, else an hash (name => value). If no argument is provided, return every option
      def [](*options)
        options = [options] unless options.is_a?(Array)
        options = @options.keys if options.length == 0

        if options.length == 1 then
          self.get(options[0])
        else
          rv = {}
          options.each do |option|
            rv[option.to_s] = self.get(option) if self.exists?(option)
          end
          rv
        end
      end

      # Returns option and non option provided arguments.
      def fetch
        [self.[], @args]
      end
    
      # Prints the help message.
      def print_help
        # Print app name
        if @app_name then
          print "#{@app_name}"
          if @app_version > 0 then print " #{@app_version}" end
          if @description then print " - #{@description}" end
          print "\n"
        end
      
        # Print usage
        if @messages["pre_usage"] then print "#{@messages["pre_usage"]}\n" end
        print "#{if @usage then @usage else "Usage: #{ARGV[0]} [OPTIONS]" end}\n"

        # Print pre_options
        if @messages["pre_options"] then print "#{@messages["pre_options"]}\n" end
        print "\nValid options are:\n"
      
        # Order options for printing
        @sorted_opts = @inserted[:name].sort do |first, second|
          @options[first][:priority] != @options[second][:priority] ? @options[first][:priority] <=> @options[second][:priority] : @inserted[:name].index(first) <=> @inserted[:name].index(second)
        end
      
        # Add options, saving max length
        popts = {}
        maxlen = -1
        @sorted_opts.each do |key|
          opt = @options[key]
        
          popt = "#{[opt[:short], opt[:long]].join(", ")}"
          popt += ("=" + (if opt[:meta] then opt[:meta] else "ARG" end)) unless [:bool, :action].include?(opt[:type])
          popts[key] = popt
          maxlen = popt.length if popt.length > maxlen
        end

        # Print options
        @sorted_opts.each do |key|
          val = popts[key]
          print "\t#{val}#{" " * (5 + (maxlen - val.length))}#{@options[key][:help]}\n"
        end
      
        # Print post_options
        if @messages["post_options"] then print "#{@messages["post_options"]}\n" end
      end
    
      #Creates a new OptionParser.
      #
      # Arguments:
      # * <em>name</em>: Application name
      # * <em>version</em>: Application version
      # * <em>name</em>: Application description
      # * <em>name</em>: Application usage
      # * <em>messages</em>: Application message for help switch. Supported keys are
      #   * <em>:pre_usage</em>: Message to print before the usage string
      #   * <em>:pre_options</em>: Message to print before the options list
      #   * <em>:post_options</em>: Message to print after the options list
      def initialize(args)
        # Initialize types
        @@valid_types = {:bool => [], :string => [String, ""], :int => [Integer, 0], :float => [Float, 0.0], :choice => [String, ""], :list => [Array, []], :action => []}
        
        # Copy arguments
        @app_name = args[:name] 
        @app_version = args[:version]
        @description = args[:description]
        @usage = args[:usage]

        # Copy messages
        messages = args[:messages] || {}
        if messages.is_a?(Hash) then @messages = messages else @console.fatal(:msg => "CowtechLib::OptionParser::initialize msgs argument must be an hash.") end
      
        # Initialize variables
        @console = Console.new
        @inserted = {:name => [], :short => [], :long => []}
        @options = {}
        @options_map = {}
        @args = []
        @cmdline = ARGV.clone
      
        self << {:name => "help", :short => "-h", :long => "--help", :type => :bool, :help => "Show this message.", :priority => 1000}
      end
    end
  end
end

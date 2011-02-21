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

module Cowtech
  module Lib
    # Class which implements a script to execute general tasks.
    # @author Shogun 

    class Script
      # Console object
      attr_reader :console
    
      # Shell object
      attr_reader :shell
      
      # Options parser
      attr_reader :options_parser
    
      # Creates a new script.
      # 
      # Arguments:
      # * <em>name</em>: Script name
      # * <em>version</em>: Script version
      # * <em>name</em>: Script description
      # * <em>name</em>: Script usage
      # * <em>name</em>: Script message for help switch. Supported keys are
      #   * <em>pre_usage</em>: Message to print before the usage string
      #   * <em>pre_options</em>: Message to print before the options list
      #   * <em>post_options</em>: Message to print after the options list
      def initialize(args)
        @console = Console.new
        @shell = Shell.new(@console)
        @options_parser = OptionParser.new(args)

        self.add_options()
        @options_parser << [
          {:name => "command-echo", :short => "-z", :long => "--command-echo", :type => :bool, :help => "Show executed commands."},
          {:name => "command-show", :short => "-V", :long => "--command-show", :type => :bool, :help => "Show executed commands' output."},
          {:name => "command-skip", :short => "-Z", :long => "--command-skip", :type => :bool, :help => "Don't really execut commands, only print them."}
        ]

        @options_parser.parse

        @console.show_commands = @options_parser["command-echo"]
        @console.show_outputs = @options_parser["command-show"]
        @console.skip_commands = @options_parser["command-skip"]

        self.run
      end
    
      # Execute a task, showing a message.
      # 
      # Arguments:
      # * <em>msg</em>: The message to show
      # * <em>show_message</em>: If show task description
      # * <em>show_end</em>: If show message exit status
      # * <em>go_up</em>: If go up one line to show exit status
      # * <em>dots</em>: If show dots after message
      def task(args)
        if args.fetch(:show_msg, true) then
          @console.write(:begin => args[:msg], :dots => args[:dots])
          @console.indent_set(3)
        end
      
        # Run the block
        rv = yield
        rv = :ok unless rv.is_a?(Symbol)
        rv = [rv, true] unless rv.is_a?(Array)
      
        # Show the result
        if args.fetch(:show_result, true) then
          @console.status(:status => rv[0], :fatal => false)
          @console.indent_set(-3)
        end

        exit(1) if rv[0] != :ok && rv[1]
      end

      # Run the script. 
      #<b> MUST BY OVERRIDEN BY SUBCLASSES!</b>
      def run
        self.console.fatal("Cowtech::Lib::Script#run must be overidden by subclasses.")
      end
    
      # Adds the command line options.
      # <b>MUST BE OVERRIDEN BY SUBCLASSES!</b>
      def add_options 
        self.console.fatal("Cowtech::Lib::Script#add_options must be overidden by subclasses.")
      end
      
      def get_binding
        binding
      end
    end
  end
end
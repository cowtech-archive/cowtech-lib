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

require "pp"
require "rexml/document"
require "rubygems"
require "open4"
require "find"
require "CowtechLib/Console"
require "CowtechLib/OptionParser"

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
      def initialize(*args)
        @console = Console.new
        @shell = Console.new(@console)
        @options_parser = OptionParser.new(*args)

        self.add_options()
        @options_parser << [
          {:name => "command-echo", :short => "-z", :long => "--command-echo", :type => :bool, :help => "Show executed commands."}
          {:name => "command-show", :short => "-V", :long => "--command-show", :type => :bool, :help => "Show executed commands' output."}
          {:name => "command-skip", :short => "-Z", :long => "--command-skip", :type => :bool, :help => "Don't really execut commands, only print them."}
        ]

        @options_parser.parse()

        @console.show_commands = @options_parser["command-echo"]
        @console.show_outputs = @options_parser["command-show"]
        @console.skip_commands = @options_parser["command-skip"]

        self.run()
      end
    
      # Execute a task, showing a message.
      # 
      # Arguments:
      # * <em>msg</em>: The message to show
      # * <em>show_message</em>: If show task description
      # * <em>show_end</em>: If show message exit status
      # * <em>go_up</em>: If go up one line to show exit status
      # * <em>dots</em>: If show dots after message
      def task(*args)
        if args[:show_msg] then
          @console.msg(:msg => msg, :dots => args[:dots], :begin => true) if args[:show_msg]
          @console.indent(3)
        end
      
        # Run the block
        rv = yield || :ok
      
        # Show the result
        @console.result(:result = rv.try("[]", 0) || rv, :fatal => rv.try("[]", 1) == nil ? true : rv.try("[]", 1)) if args[:show_result]
        @console.indent(-3)
      end

      # Run the script. 
      #<b> MUST BY OVERRIDEN BY SUBCLASSES!</b>
      def run
        self.console.fatal("Script::run() must be overidden by subclass")
      end
    
      # Adds the command line options.
      # <b>MUST BE OVERRIDEN BY SUBCLASSES!</b>
      def add_options 
        self.console.fatal("Cowtech::Lib::Script::add_options must be overidden by subclass.")
      end
      
      # Executes the script
      def self.execute!
        self.new.run
      end
    end
  end
end

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

require "rexml/document"

class Object
  def force_array
    self.is_a?(Array) ? self : [self]
  end
end

class Hash
  def method_missing(method, *arg)
    # PER ORA SUPPORTIAMO SOLO I GETTER
    self[method.to_sym]
  end
  
  def respond_to?(method)
    self.has_key?(method.to_sym)
  end
end

module Cowtech
  module Lib
    # A class which provides some method to operate with files and to format pretty messages.
    # @author Shogun
    class Console
      # Indentation level
      attr_accessor :indent_level

      # Whether show executed commands
      attr_accessor :show_commands

      # Whether show output of executed commands
      attr_accessor :show_outputs

      # Whether simply print commands rather than executing them
      attr_accessor :skip_commands

      # Exit status for commands
      attr_reader :statuses

      # Indentation string(s)
      attr_accessor :indentator

      # Sets indentation level.
      # Arguments:
      # * <em>indent</em>: The new indentation level
      # * <em></em>: If the level is absolute or relative to the current level
      def indent_set(level, absolute = false)
        @indent_level = [(!absolute ? @indent_level : 0) + level, 0].max
      end

      # Resets indentation level to 0.
      def indent_reset
        @indent_level = 0
      end

      # Execute codes in an indented block
      def indent_region(level, absolute = false)
        old_level = @indent_level
        self.indent_set(level, absolute)
        yield
        @indent_level = old_level      
      end

      # Indents a message.
      # 
      # Arguments:
      # * <em>msg</em>: The message to indent
      # * <em>add_additional</em>: Whether add extra space to align to initial message "*"
      # Returns: The indentated message
      def indent(msg, level = nil)
        (@@indentator * (level || @indent_level)) + msg
      end

      # Substitute tag with color.
      # 
      # Arguments:
      # * <em>node</em>: The node which operate on
      # * <em>stack</em>: The stack of old styles. <b>Do not set this by yourself!</b>
      # 
      # Returns: The new text
      def parse_message(node, stack = [])
        rv = ""
        styles = (node.name == "text" and node.attributes["style"]) ? node.attributes["style"].split(" ") : nil

        # Add style of current tag
        if styles then
          styles.each do |style|
            rv += @@styles[style] || ""
          end

          stack.push(styles)
        end

        # Now parse subnodes
        node.children.each do |child|
          if child.node_type == :text then
            rv += child.to_s
          elsif child.name == "text" then
            rv += self.parse_message(child, stack)
          end
        end

        # Remove style of current tag
        if styles then 
          stack.pop()

          # Restore previous style
          (stack.pop || ["default"]).each do |style|
            rv += @@styles[style]
          end
        end

        rv
      end

      # Prints a message.
      # Arguments:
      # * <em>msg</em>: The message to print
      # * <em>dots</em>: Whether add "..." to the message
      # * <em>newline</em>: Whether add a newline to the message
      # * <em>plain</em>: Whether ignore tags
      # * <em>must_indent</em>: Whether indent the message
      # * <em>internal</em>: If the method is called by another method. <b>Do not set this by yourself!</b>
      def write(args)
        msg = args[:msg]

        # Check some alternative syntax
        [:begin, :warn, :error, :debug, :info, :right, :end].each do |t|
          if args[t] then
            msg = args[t]
            args[:type] = t
            args[t] = nil
          end
        end
        args[:fatal] = true if args[:status] == :fail

        # Check for specific msg type
        if [:begin, :warn, :error, :debug, :info].include?(args[:type]) then
          mc = {:begin => "bold green", :warn => "bold yellow", :error => "bold red", :debug => "magenta", :info => "bold cyan"}
          color = args[:color] || mc[args[:type]]
          
          if args[:full_color] then
            msg = self.indent("<text style=\"#{color}\">#{msg}</text>")
          else
            msg = " <text style=\"#{color}\">*</text> #{self.indent(msg)}" 
          end
        else # Add dots and indentation if needed
          msg = self.indent(msg + (args.fetch(:dots, true) ? "..." : ""), args[:indent] ? args[:indent] : @indent_level)
        end
        
        # Parse the message
        if !args[:plain] then
          begin
            xml = "<text>#{msg}</text>"
            msg = self.parse_message(REXML::Document.new(xml).root)
          rescue Exception => e
            print "[ERROR] Invalid message tagging, check XML syntax (or color requested) of the following message:\n\n\t#{xml}\n\n"
            print "\tThe errors was: #{e.message} (#{e.class.to_s})\n\n"
            exit(1)
          end
        end

        # Add newline if needed
        msg += "\n" if args.fetch(:newline, true)

        if args[:internal] then 
          msg 
        else 
          if [:end, :right].include?(args[:type]) then
            # Get screen width
            @tty_width = `tput cols`.to_i if @tty_width < 0

            # Get padding
            pad = @tty_width - msg.inspect.gsub(/(\\e\[[0-9]+m)|(\")|(\\n)/, "").length

            print "\033[A" if args[:up]
            print "\033[0G\033[#{pad}C"
          end

          print(msg)
        end

        exit(args[:code] || 0) if args[:exit_after] || args[:fatal]
      end

      # Syntatic sugar
      # Prints a warning message.
      def warn(msg, args = nil)
        args ||= {}
        
        if msg.is_a?(Hash) then
          args.merge!(msg)
        else
          args[:msg] = msg
        end
        
        args[:warn] = args[:msg]

        self.write(args)
      end

      # Prints an error message.
      def error(msg, args = nil)
        args ||= {}

        if msg.is_a?(Hash) then
          args.merge!(msg)
        else
          args[:msg] = msg
        end

        args[:error] = args[:msg]

        self.write(args)
      end

      # Prints and error message then abort.
      def fatal(msg, args = nil)
        args ||= {}

        if msg.is_a?(Hash) then
          args.merge!(msg)
        else
          args[:msg] = msg
        end

        args[:error] = args[:msg]
        args[:exit_after] = true
        args[:code] ||= 1

        self.write(args)
      end

      # Prints an error status
      def status(status, args = nil)
        args ||= {}

        if status.is_a?(Hash) then
          args.merge!(status)
        else
          args[:status] = status
        end

        status = status.is_a?(Hash) ? status[:status] : status
        args[:end] = @@statuses[status] || @@statuses[:ok]
        args[:dots] = false
        args[:up] = true if args[:up] == nil
        self.write(args)
      end

      # Read input from the user.
      # 
      # Arguments:
      # * <em>msg</em>: The prompt to show
      # * <em>valids</em>: A list of regexp to validate the input
      # * <em>case_sensitive</em>: Wheter the validation is case_sensitive
      # 
      # Returns: The read input
      def read(args)
        # Adjust prompt
        msg = args[:msg] + ((msg !~ /([:?](\s*))$/) ? ":" : "")
        msg += " " if msg !~ / ^/

        # Turn choices into regular expressions
        regexps = (args[:valids] || []).force_array.collect do |valid|
          if !valid.is_a?(Regexp) then
            valid = Regexp.new((valid !~ /^\^/ ? "^" : "") + valid + (valid !~ /\$$/ ? "$" : ""), Regexp::EXTENDED + (args[:case_sensitive] ? Regexp::IGNORECASE : 0), "U")
          else
            valid
          end
        end

        rv = nil

        # Read input
        while true do
          # Show message
          print(msg)

          # Get reply
          bufs = gets.chop()

          # If we don't have any regexp
          if regexps.length == 0 then
            rv = bufs
            break
          end

          # Validate inputs
          regexps.each do |re|
            if bufs =~ re then
              rv = bufs
              break
            end
          end

          break if rv
          self.write(:warn => "Sorry, your reply was not understood. Please try again")
        end

        rv
      end

      # Create a new Console.
      def initialize
        @indent_level = 0
        @show_commands = false
        @show_outputs = false
        @skip_commands = false
        @tty_width = -1
        @@indentator= " "        

        @@styles = {
          # Default color
          "default" => "\33[0m",
          # Text style
          "bold" => "\33[1m", "underline" => "\33[4m", "blink" => "\33[5m", "reverse" => "\33[7m", "concealed" => "\33[8m",
          # Foreground colors
          "black" => "\33[30m", "red" => "\33[31m", "green" => "\33[32m", "yellow" => "\33[33m", "blue" => "\33[34m", "magenta" => "\33[35m", "cyan" => "\33[36m", "white" => "\33[37m",
          # Background colors
          "bg_black" => "\33[40m", "bg_red" => "\33[41m", "bg_green" => "\33[42m", "bg_yellow" => "\33[43m", "bg_blue" => "\33[44m", "bg_magenta" => "\33[45m", "bg_cyan" => "\33[46m", "bg_white" => "\33[47m"
        }

        @@statuses = {
          :ok => '<text style="bold blue">[ <text style="bold green">OK</text> ]</text> ',
          :pass => '<text style="bold blue">[<text style="bold cyan">PASS</text>]</text> ',
          :fail => '<text style="bold blue">[<text style="bold red">FAIL</text>]</text> ',
          :warn => '<text style="bold blue">[<text style="bold yellow">WARN</text>]</text> ',
        }
      end
    end
  end
end
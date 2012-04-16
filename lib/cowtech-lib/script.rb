# encoding: utf-8
#
# This file is part of the cowtech-lib gem. Copyright (C) 2011 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
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
					{name: "command-echo", short: "-z", long: "--command-echo", type: :bool, help: "Show executed commands."},
						{name: "command-show", short: "-V", long: "--command-show", type: :bool, help: "Show executed commands' output."},
						{name: "command-skip", short: "-Z", long: "--command-skip", type: :bool, help: "Don't really execut commands, only print them."}
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
					@console.write(begin: args[:msg], dots: args[:dots])
					@console.indent_set(3)
				end

				# Run the block
				rv = yield
				rv = :ok if !rv.is_a?(Symbol)
				rv = [rv, true] if !rv.is_a?(Array)

				# Show the result
				@console.status(status: rv[0], fatal: false) if args.fetch(:show_result, true)
				@console.indent_set(-3) if args.fetch(:show_msg, true)

				exit(1) if rv[0] != :ok && rv[1]
				rv
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